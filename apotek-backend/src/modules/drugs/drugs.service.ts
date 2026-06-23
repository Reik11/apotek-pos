import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DrugsService {
  constructor(private prisma: PrismaService) {}

  // AMBIL SEMUA OBAT
  async findAll(search?: string, category?: string, outletId?: string) {
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
          where: {
            stock: { gt: 0 },
            outletId: outletId || undefined,
          },
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
        batches: { orderBy: { expiredDate: 'asc' } },
      },
  });
  if (!drug) throw new NotFoundException('Obat tidak ditemukan');

  // Hitung apakah data sudah stale (lebih dari 7 hari)
  const isStale = drug.lastApiSync
    ? new Date().getTime() - drug.lastApiSync.getTime() >
      7 * 24 * 60 * 60 * 1000
    : true;

  return {
    ...drug,
    apiDataAvailable: drug.lastApiSync !== null,
    apiDataStale: isStale,
    fdaInfo: drug.lastApiSync
      ? {
          indications: drug.fdaIndications,
          sideEffects: drug.fdaSideEffects,
          dosage: drug.fdaDosage,
          warnings: drug.fdaWarnings,
          contraindications: drug.fdaContraindications,
        }
      : null,
  };
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

  // HAPUS OBAT (hard delete)
  async remove(id: string) {
    await this.findOne(id);
    // Hapus batch terlebih dahulu
    await this.prisma.drugBatch.deleteMany({ where: { drugId: id } });
    return this.prisma.drug.delete({ where: { id } });
  }

  // TAMBAH STOK / BATCH BARU
  async addBatch(data: {
    drugId: string;
    batchNumber: string;
    stock: number;
    buyPrice: number;
    expiredDate: string;
    supplierId?: string;
    outletId?: string;
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
      outletId: data.outletId || null,
    },
  });
}

  // CEK OBAT HAMPIR EXPIRED
  async getExpiringDrugs(days: number = 90, outletId?: string) {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + days);

    return this.prisma.drugBatch.findMany({
      where: {
        expiredDate: { lte: futureDate },
        stock: { gt: 0 },
        outletId: outletId || undefined,
      },
      include: { drug: true },
      orderBy: { expiredDate: 'asc' },
    });
  }

  // CEK STOK KRITIS
  async getLowStockDrugs(outletId?: string) {
    const drugs = await this.prisma.drug.findMany({
      where: { isActive: true },
      include: {
        batches: {
          where: {
            stock: { gt: 0 },
            outletId: outletId || undefined,
          },
        },
      },
    });

    return drugs.filter((drug) => {
      const totalStock = drug.batches.reduce((sum, b) => sum + b.stock, 0);
      return totalStock <= drug.minStock;
    });
  }

  // Alert stok menipis & kadaluarsa
  async getAlerts(outletId?: string) {
    const ninetyDaysFromNow = new Date();
    ninetyDaysFromNow.setDate(ninetyDaysFromNow.getDate() + 90);

    const drugs = await this.prisma.drug.findMany({
      where: { isActive: true },
      include: {
        batches: {
          where: {
            stock: { gt: 0 },
            outletId: outletId || undefined,
          },
        },
      },
    });

    const lowStock: any[] = [];
    const nearExpiry: any[] = [];

    for (const drug of drugs) {
      const totalStock = drug.batches.reduce((sum, b) => sum + b.stock, 0);
      if (totalStock <= drug.minStock) {
        lowStock.push({
          id: drug.id,
          name: drug.name,
          currentStock: totalStock,
          minStock: drug.minStock,
        });
      }

      const expiringBatches = drug.batches.filter(
        (b) => new Date(b.expiredDate) <= ninetyDaysFromNow,
      );
      if (expiringBatches.length > 0) {
        nearExpiry.push({
          id: drug.id,
          name: drug.name,
          batches: expiringBatches.map((b) => ({
            batchNumber: b.batchNumber,
            stock: b.stock,
            expiredDate: b.expiredDate,
          })),
        });
      }
    }

    return { lowStock, nearExpiry };
  }
}