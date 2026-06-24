import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TransactionsService {
  constructor(private prisma: PrismaService) {}

  // BUAT TRANSAKSI BARU (KASIR)
  async create(data: {
    cashierId: string;
    items: { drugId: string; quantity: number }[];
    paymentMethod: any;
    amountPaid: number;
    discountType?: string;
    discountValue?: number;
    notes?: string;
  }) {
    // Ambil profile cashier & outletId
    const cashier = await this.prisma.user.findUnique({
      where: { id: data.cashierId },
      select: { outletId: true },
    });

    // 0. Cek shift aktif kasir
    const activeShift = await this.prisma.cashShift.findFirst({
      where: { cashierId: data.cashierId, status: 'OPEN' },
    });
    if (!activeShift) {
      throw new BadRequestException(
        'Laci kasir belum dibuka. Anda harus membuka shift kasir terlebih dahulu.',
      );
    }

    // Hitung total & validasi stok
    let subtotal = 0;
    const itemsWithBatch: {
        drugId: string;
        batchId: string;
        quantity: number;
        sellPrice: number;
        subtotal: number;
    }[] = [];

    for (const item of data.items) {
      // Ambil obat
      const drug = await this.prisma.drug.findUnique({
        where: { id: item.drugId },
      });
      if (!drug) throw new NotFoundException(`Obat ${item.drugId} tidak ditemukan`);

      // Ambil batch dengan stok tersedia di outlet cashier (FIFO - expired terdekat dulu)
      const batch = await this.prisma.drugBatch.findFirst({
        where: {
          drugId: item.drugId,
          stock: { gte: item.quantity },
          outletId: cashier?.outletId || null,
        },
        orderBy: { expiredDate: 'asc' },
      });
      if (!batch) {
        throw new BadRequestException(`Stok ${drug.name} tidak cukup di cabang ini`);
      }

      const itemSubtotal = drug.sellPrice * item.quantity;
      subtotal += itemSubtotal;

      itemsWithBatch.push({
        drugId: item.drugId,
        batchId: batch.id,
        quantity: item.quantity,
        sellPrice: drug.sellPrice,
        subtotal: itemSubtotal,
      });
    }

    // Hitung Diskon
    const discountType = data.discountType || 'NOMINAL';
    const discountValue = data.discountValue || 0;
    let discountAmount = 0;

    if (discountType === 'PERCENT') {
      discountAmount = subtotal * (discountValue / 100);
    } else {
      discountAmount = discountValue;
    }

    const totalAmount = Math.max(0, subtotal - discountAmount);

    // Validasi uang bayar
    if (data.amountPaid < totalAmount) {
      throw new BadRequestException('Uang bayar kurang');
    }

    const change = data.amountPaid - totalAmount;

    // Simpan transaksi ke database
    const transaction = await this.prisma.transaction.create({
      data: {
        cashierId: data.cashierId,
        shiftId: activeShift.id,
        subtotal,
        discountType,
        discountValue,
        discountAmount,
        totalAmount,
        paymentMethod: data.paymentMethod,
        amountPaid: data.amountPaid,
        change,
        notes: data.notes,
        outletId: cashier?.outletId || null,
        items: {
          create: itemsWithBatch,
        },
      },
      include: {
        items: { include: { drug: true } },
        outlet: true,
      },
    });

    // Kurangi stok setiap batch
    for (const item of itemsWithBatch) {
      await this.prisma.drugBatch.update({
        where: { id: item.batchId },
        data: { stock: { decrement: item.quantity } },
      });
    }

    return transaction;
  }

  // AMBIL SEMUA TRANSAKSI
  async findAll(startDate?: string, endDate?: string, outletId?: string) {
    return this.prisma.transaction.findMany({
      where: {
        createdAt: {
          gte: startDate ? new Date(startDate) : undefined,
          lte: endDate ? new Date(endDate) : undefined,
        },
        outletId: outletId || undefined,
      },
      include: {
        cashier: { select: { id: true, name: true } },
        items: { include: { drug: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // AMBIL SATU TRANSAKSI
  async findOne(id: string) {
    const tx = await this.prisma.transaction.findUnique({
      where: { id },
      include: {
        cashier: { select: { id: true, name: true } },
        items: { include: { drug: true } },
        outlet: true,
      },
    });
    if (!tx) throw new NotFoundException('Transaksi tidak ditemukan');
    return tx;
  }

  // RINGKASAN PENJUALAN HARI INI
  async getDailySummary(outletId?: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const transactions = await this.prisma.transaction.findMany({
      where: {
        createdAt: { gte: today, lt: tomorrow },
        status: 'COMPLETED',
        outletId: outletId || undefined,
      },
    });

    const totalRevenue = transactions.reduce((sum, t) => sum + t.totalAmount, 0);
    const totalTransactions = transactions.length;

    return {
      date: today.toISOString().split('T')[0],
      totalTransactions,
      totalRevenue,
      averageTransaction: totalTransactions > 0 ? totalRevenue / totalTransactions : 0,
    };
  }

  // VOID TRANSAKSI (CANCEL & BALIKKAN STOK)
  async voidTransaction(id: string) {
    const tx = await this.findOne(id);
    if (tx.status === 'CANCELLED') {
      throw new BadRequestException('Transaksi sudah dibatalkan/void');
    }
    if (tx.status === 'REFUNDED') {
      throw new BadRequestException('Transaksi sudah di-refund');
    }

    return this.prisma.$transaction(async (txPrisma) => {
      // 1. Kembalikan stok untuk setiap item
      for (const item of tx.items) {
        await txPrisma.drugBatch.update({
          where: { id: item.batchId },
          data: { stock: { increment: item.quantity } },
        });
      }

      // 2. Ubah status transaksi menjadi CANCELLED
      return txPrisma.transaction.update({
        where: { id },
        data: { status: 'CANCELLED' },
        include: {
          cashier: { select: { id: true, name: true } },
          items: { include: { drug: true } },
          outlet: true,
        },
      });
    });
  }
}