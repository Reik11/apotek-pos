import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OrdersService {
  constructor(private prisma: PrismaService) {}

  // BUAT ORDER BARU (PASIEN)
  async create(data: {
    patientId: string;
    items: { drugId: string; quantity: number }[];
    notes?: string;
  }) {
    // Validasi stok & hitung total
    let totalAmount = 0;
    const itemsData: {
        drugId: string;
        quantity: number;
        price: number;
        subtotal: number;
    }[] = [];

    for (const item of data.items) {
      const drug = await this.prisma.drug.findUnique({
        where: { id: item.drugId },
        include: {
          batches: {
            where: { stock: { gt: 0 } },
            orderBy: { expiredDate: 'asc' },
          },
        },
      });

      if (!drug) throw new NotFoundException(`Obat tidak ditemukan`);

      const totalStock = drug.batches.reduce((sum, b) => sum + b.stock, 0);
      if (totalStock < item.quantity) {
        throw new BadRequestException(`Stok ${drug.name} tidak cukup`);
      }

      const subtotal = drug.sellPrice * item.quantity;
      totalAmount += subtotal;

      itemsData.push({
        drugId: item.drugId,
        quantity: item.quantity,
        price: drug.sellPrice,
        subtotal,
      });
    }

    // Generate kode order unik
    const orderCode = `APT-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;

    // Simpan order
    return this.prisma.order.create({
      data: {
        patientId: data.patientId,
        totalAmount,
        orderCode,
        notes: data.notes,
        items: { create: itemsData },
      },
      include: {
        items: { include: { drug: true } },
        patient: { select: { id: true, name: true, email: true } },
      },
    });
  }

  // AMBIL SEMUA ORDER (ADMIN/APOTEKER)
  async findAll(status?: string) {
    return this.prisma.order.findMany({
      where: { status: status as any },
      include: {
        items: { include: { drug: true } },
        patient: { select: { id: true, name: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // AMBIL ORDER MILIK PASIEN
  async findByPatient(patientId: string) {
    return this.prisma.order.findMany({
      where: { patientId },
      include: {
        items: { include: { drug: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // AMBIL SATU ORDER BY ID
  async findOne(id: string) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: {
        items: { include: { drug: true } },
        patient: { select: { id: true, name: true, email: true } },
      },
    });
    if (!order) throw new NotFoundException('Order tidak ditemukan');
    return order;
  }

  // AMBIL ORDER BY KODE (untuk kasir scan QR)
  async findByCode(orderCode: string) {
    const order = await this.prisma.order.findUnique({
      where: { orderCode },
      include: {
        items: { include: { drug: true } },
        patient: { select: { id: true, name: true, email: true } },
      },
    });
    if (!order) throw new NotFoundException('Kode order tidak valid');
    return order;
  }

  // UPDATE STATUS ORDER (APOTEKER/KASIR)
  async updateStatus(id: string, status: string, paymentProof?: string) {
    await this.findOne(id);
    return this.prisma.order.update({
      where: { id },
      data: {
        status: status as any,
        paymentProof: paymentProof || undefined,
      },
      include: {
        items: { include: { drug: true } },
        patient: { select: { id: true, name: true, email: true } },
      },
    });
  }

  // KONFIRMASI PENGAMBILAN (KASIR SCAN QR)
  async confirmPickup(orderCode: string) {
    const order = await this.findByCode(orderCode);

    if (order.status !== 'READY') {
      throw new BadRequestException(
        `Order belum siap diambil. Status saat ini: ${order.status}`
      );
    }

    // Update status jadi COMPLETED
    const completed = await this.prisma.order.update({
      where: { orderCode },
      data: { status: 'COMPLETED' },
      include: {
        items: { include: { drug: true } },
        patient: { select: { id: true, name: true } },
      },
    });

    // Kurangi stok obat
    for (const item of order.items) {
      const batch = await this.prisma.drugBatch.findFirst({
        where: { drugId: item.drugId, stock: { gte: item.quantity } },
        orderBy: { expiredDate: 'asc' },
      });
      if (batch) {
        await this.prisma.drugBatch.update({
          where: { id: batch.id },
          data: { stock: { decrement: item.quantity } },
        });
      }
    }

    return completed;
  }
}