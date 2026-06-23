import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PurchaseOrdersService {
  constructor(private prisma: PrismaService) {}

  async create(data: {
    supplierId: string;
    items: { drugId: string; quantity: number; price: number }[];
  }) {
    // 1. Verify supplier exists
    const supplier = await this.prisma.supplier.findUnique({
      where: { id: data.supplierId },
    });
    if (!supplier) {
      throw new NotFoundException('Supplier tidak ditemukan');
    }

    // 2. Fetch drug details to get drug names and verify existence
    const drugIds = data.items.map((i) => i.drugId);
    const drugs = await this.prisma.drug.findMany({
      where: { id: { in: drugIds } },
    });

    if (drugs.length !== drugIds.length) {
      throw new BadRequestException('Beberapa obat tidak ditemukan');
    }

    const drugMap = new Map(drugs.map((d) => [d.id, d.name]));

    // 3. Prepare PO items and calculate totals
    let totalAmount = 0;
    const poItemsData = data.items.map((item) => {
      const subtotal = item.quantity * item.price;
      totalAmount += subtotal;
      return {
        drugId: item.drugId,
        drugName: drugMap.get(item.drugId) || 'Obat Tidak Dikenal',
        quantity: item.quantity,
        price: item.price,
        subtotal,
      };
    });

    // 4. Create PO inside transaction
    return this.prisma.purchaseOrder.create({
      data: {
        supplierId: data.supplierId,
        totalAmount,
        status: 'PENDING',
        items: {
          create: poItemsData,
        },
      },
      include: {
        supplier: true,
        items: true,
      },
    });
  }

  async findAll() {
    return this.prisma.purchaseOrder.findMany({
      include: {
        supplier: { select: { id: true, name: true } },
        items: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const po = await this.prisma.purchaseOrder.findUnique({
      where: { id },
      include: {
        supplier: true,
        items: true,
      },
    });
    if (!po) {
      throw new NotFoundException('Purchase Order tidak ditemukan');
    }
    return po;
  }

  async updateStatus(
    id: string,
    data: {
      status: 'PENDING' | 'ORDERED' | 'RECEIVED' | 'CANCELLED';
      receiveDetails?: {
        drugId: string;
        batchNumber: string;
        expiredDate: string;
      }[];
    },
  ) {
    const po = await this.findOne(id);

    if (po.status === 'RECEIVED') {
      throw new BadRequestException('Purchase Order sudah diterima dan tidak dapat diubah lagi');
    }
    if (po.status === 'CANCELLED') {
      throw new BadRequestException('Purchase Order sudah dibatalkan');
    }

    // If changing to RECEIVED, we must create DrugBatches and increase stock
    if (data.status === 'RECEIVED') {
      if (!data.receiveDetails || data.receiveDetails.length === 0) {
        throw new BadRequestException(
          'Detail penerimaan obat (Batch Number & Expired Date) harus diisi saat menerima barang',
        );
      }

      const detailsMap = new Map(
        data.receiveDetails.map((d) => [
          d.drugId,
          { batchNumber: d.batchNumber, expiredDate: new Date(d.expiredDate) },
        ]),
      );

      // Verify all items in PO have corresponding receive details
      for (const item of po.items) {
        if (!detailsMap.has(item.drugId)) {
          throw new BadRequestException(
            `Detail penerimaan untuk obat ${item.drugName} belum diisi`,
          );
        }
      }

      // Execute transaction to update status and insert drug batches
      return this.prisma.$transaction(async (tx) => {
        // Create DrugBatch for each item
        for (const item of po.items) {
          const detail = detailsMap.get(item.drugId)!;
          await tx.drugBatch.create({
            data: {
              drugId: item.drugId,
              batchNumber: detail.batchNumber,
              stock: item.quantity,
              buyPrice: item.price,
              expiredDate: detail.expiredDate,
              supplierId: po.supplierId,
            },
          });
        }

        // Update PO status
        return tx.purchaseOrder.update({
          where: { id },
          data: { status: 'RECEIVED' },
          include: {
            supplier: true,
            items: true,
          },
        });
      });
    }

    // For other status updates (e.g. PENDING -> ORDERED or CANCELLED)
    return this.prisma.purchaseOrder.update({
      where: { id },
      data: { status: data.status },
      include: {
        supplier: true,
        items: true,
      },
    });
  }
}
