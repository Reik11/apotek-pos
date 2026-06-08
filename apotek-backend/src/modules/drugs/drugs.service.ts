import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DrugsService {
  constructor(private prisma: PrismaService) {}

  // AMBIL SEMUA OBAT
  async findAll(search?: string, category?: string) {
    return this.prisma.drug.findMany({
      where: {
        isActive: true,
        AND: [
          search ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { genericName: { contains: search, mode: 'insensitive' } },
              { activeIngredient: { contains: search, mode: 'insensitive' } },
            ],
          } : {},
          category ? { category: category as any } : {},
        ],
      },
      include: {
        batches: {
          where: { stock: { gt: 0 } },
          orderBy: { expiredDate: 'asc' },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  // AMBIL SATU OBAT BY ID
  async findOne(id: string) {
    const drug = await this.prisma.drug.findUnique({
      where: { id },
      include: {
        batches: {
          orderBy: { expiredDate: 'asc' },
        },
      },
    });
    if (!drug) throw new NotFoundException('Obat tidak ditemukan');
    return drug;
  }

  // TAMBAH OBAT BARU
  async create(data: {
    name: string;
    genericName?: string;
    brandName?: string;
    activeIngredient?: string;
    category?: any;
    type?: any;
    unit?: string;
    minStock?: number;
    sellPrice: number;
    buyPrice: number;
    rxcui?: string;
    bpomNumber?: string;
    description?: string;
  }) {
    return this.prisma.drug.create({ data });
  }

  // UPDATE OBAT
  async update(id: string, data: any) {
    await this.findOne(id);
    return this.prisma.drug.update({ where: { id }, data });
  }

  // HAPUS OBAT (soft delete)
  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.drug.update({
      where: { id },
      data: { isActive: false },
    });
  }

  // TAMBAH STOK / BATCH BARU
  async addBatch(data: {
    drugId: string;
    batchNumber: string;
    stock: number;
    buyPrice: number;
    expiredDate: string;
    supplierId?: string;
  }) {
  await this.findOne(data.drugId);
  return this.prisma.drugBatch.create({
    data: {
      drugId: data.drugId,
      batchNumber: data.batchNumber,
      stock: data.stock,
      buyPrice: data.buyPrice,
      expiredDate: new Date(data.expiredDate),
      supplierId: data.supplierId || null,
    },
  });
}

  // CEK OBAT HAMPIR EXPIRED
  async getExpiringDrugs(days: number = 90) {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + days);

    return this.prisma.drugBatch.findMany({
      where: {
        expiredDate: { lte: futureDate },
        stock: { gt: 0 },
      },
      include: { drug: true },
      orderBy: { expiredDate: 'asc' },
    });
  }

  // CEK STOK KRITIS
  async getLowStockDrugs() {
    const drugs = await this.prisma.drug.findMany({
      where: { isActive: true },
      include: {
        batches: { where: { stock: { gt: 0 } } },
      },
    });

    return drugs.filter((drug) => {
      const totalStock = drug.batches.reduce((sum, b) => sum + b.stock, 0);
      return totalStock <= drug.minStock;
    });
  }
}