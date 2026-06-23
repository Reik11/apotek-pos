import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  // LAPORAN PENJUALAN
  async getSalesReport(period: 'daily' | 'weekly' | 'monthly' | 'yearly', outletId?: string) {
    const now = new Date();
    let startDate: Date;

    switch (period) {
      case 'daily':
        startDate = new Date(now.setHours(0, 0, 0, 0));
        break;
      case 'weekly':
        startDate = new Date(now.setDate(now.getDate() - 7));
        break;
      case 'monthly':
        startDate = new Date(now.setMonth(now.getMonth() - 1));
        break;
      case 'yearly':
        startDate = new Date(now.setFullYear(now.getFullYear() - 1));
        break;
    }

    const transactions = await this.prisma.transaction.findMany({
      where: {
        createdAt: { gte: startDate },
        status: 'COMPLETED',
        outletId: outletId || undefined,
      },
      include: {
        items: { include: { drug: true } },
        cashier: { select: { name: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    // Hitung total
    const totalRevenue = transactions.reduce((sum, t) => sum + t.totalAmount, 0);
    const totalTransactions = transactions.length;
    const totalItems = transactions.reduce(
      (sum, t) => sum + t.items.reduce((s, i) => s + i.quantity, 0), 0
    );

    // Obat terlaris
    const drugSales: Record<string, { name: string; quantity: number; revenue: number }> = {};
    for (const tx of transactions) {
      for (const item of tx.items) {
        if (!drugSales[item.drugId]) {
          drugSales[item.drugId] = { name: item.drug.name, quantity: 0, revenue: 0 };
        }
        drugSales[item.drugId].quantity += item.quantity;
        drugSales[item.drugId].revenue += item.subtotal;
      }
    }

    const topDrugs = Object.values(drugSales)
      .sort((a, b) => b.quantity - a.quantity)
      .slice(0, 10);

    // Breakdown per metode pembayaran
    const paymentBreakdown: Record<string, number> = {};
    for (const tx of transactions) {
      const method = tx.paymentMethod;
      paymentBreakdown[method] = (paymentBreakdown[method] || 0) + tx.totalAmount;
    }

    // Grafik penjualan per hari
    const dailyChart: Record<string, number> = {};
    for (const tx of transactions) {
      const date = tx.createdAt.toISOString().split('T')[0];
      dailyChart[date] = (dailyChart[date] || 0) + tx.totalAmount;
    }

    return {
      period,
      startDate,
      summary: {
        totalRevenue,
        totalTransactions,
        totalItems,
        averageTransaction: totalTransactions > 0
          ? totalRevenue / totalTransactions : 0,
      },
      topDrugs,
      paymentBreakdown,
      dailyChart: Object.entries(dailyChart).map(([date, revenue]) => ({
        date,
        revenue,
      })),
    };
  }

  // LAPORAN INVENTARIS
  async getInventoryReport(outletId?: string) {
    const drugs = await this.prisma.drug.findMany({
      where: { isActive: true },
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

    const report = drugs.map((drug) => {
      const totalStock = drug.batches.reduce((sum, b) => sum + b.stock, 0);
      const nearestExpiry = drug.batches.find((b) => b.stock > 0)?.expiredDate;
      const inventoryValue = totalStock * drug.buyPrice;

      return {
        id: drug.id,
        name: drug.name,
        category: drug.category,
        type: drug.type,
        totalStock,
        minStock: drug.minStock,
        isLowStock: totalStock <= drug.minStock,
        nearestExpiry,
        sellPrice: drug.sellPrice,
        buyPrice: drug.buyPrice,
        inventoryValue,
      };
    });

    // Total nilai inventaris
    const totalInventoryValue = report.reduce((sum, d) => sum + d.inventoryValue, 0);
    const lowStockCount = report.filter((d) => d.isLowStock).length;
    const totalDrugs = report.length;

    return {
      summary: {
        totalDrugs,
        lowStockCount,
        totalInventoryValue,
      },
      drugs: report,
    };
  }

  // LAPORAN OBAT KADALUARSA
  async getExpiryReport(outletId?: string) {
    const now = new Date();

    const in30Days = new Date();
    in30Days.setDate(in30Days.getDate() + 30);

    const in90Days = new Date();
    in90Days.setDate(in90Days.getDate() + 90);

    const batches = await this.prisma.drugBatch.findMany({
      where: {
        expiredDate: { lte: in90Days },
        stock: { gt: 0 },
        outletId: outletId || undefined,
      },
      include: { drug: true },
      orderBy: { expiredDate: 'asc' },
    });

    const expired = batches.filter((b) => b.expiredDate < now);
    const critical = batches.filter(
      (b) => b.expiredDate >= now && b.expiredDate <= in30Days
    );
    const warning = batches.filter(
      (b) => b.expiredDate > in30Days && b.expiredDate <= in90Days
    );

    return {
      summary: {
        expiredCount: expired.length,
        criticalCount: critical.length,
        warningCount: warning.length,
      },
      expired: expired.map((b) => ({
        batchNumber: b.batchNumber,
        drugName: b.drug.name,
        stock: b.stock,
        expiredDate: b.expiredDate,
        daysUntilExpiry: Math.ceil(
          (b.expiredDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        ),
      })),
      critical: critical.map((b) => ({
        batchNumber: b.batchNumber,
        drugName: b.drug.name,
        stock: b.stock,
        expiredDate: b.expiredDate,
        daysUntilExpiry: Math.ceil(
          (b.expiredDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        ),
      })),
      warning: warning.map((b) => ({
        batchNumber: b.batchNumber,
        drugName: b.drug.name,
        stock: b.stock,
        expiredDate: b.expiredDate,
        daysUntilExpiry: Math.ceil(
          (b.expiredDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        ),
      })),
    };
  }

  // DASHBOARD SUMMARY
  async getDashboardSummary(outletId?: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const in30Days = new Date();
    in30Days.setDate(in30Days.getDate() + 30);

    // Penjualan hari ini
    const todayTransactions = await this.prisma.transaction.findMany({
      where: {
        createdAt: { gte: today, lt: tomorrow },
        status: 'COMPLETED',
        outletId: outletId || undefined,
      },
    });

    // Order pending
    const pendingOrders = await this.prisma.order.count({
      where: {
        status: 'PENDING',
        outletId: outletId || undefined,
      },
    });

    // Stok kritis
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
    const lowStockCount = drugs.filter((d) => {
      const total = d.batches.reduce((s, b) => s + b.stock, 0);
      return total <= d.minStock;
    }).length;

    // Obat near expired (30 hari)
    const nearExpiryCount = await this.prisma.drugBatch.count({
      where: {
        expiredDate: { lte: in30Days },
        stock: { gt: 0 },
        outletId: outletId || undefined,
      },
    });

    const todayRevenue = todayTransactions.reduce(
      (sum, t) => sum + t.totalAmount, 0
    );

    // Grafik penjualan 7 hari terakhir
    const salesChart: { date: string; revenue: number }[] = [];
    for (let i = 6; i >= 0; i--) {
      const dayStart = new Date();
      dayStart.setHours(0, 0, 0, 0);
      dayStart.setDate(dayStart.getDate() - i);
      const dayEnd = new Date(dayStart);
      dayEnd.setDate(dayEnd.getDate() + 1);

      const dayTxs = await this.prisma.transaction.findMany({
        where: {
          createdAt: { gte: dayStart, lt: dayEnd },
          status: 'COMPLETED',
          outletId: outletId || undefined,
        },
        select: { totalAmount: true },
      });
      const revenue = dayTxs.reduce((s, t) => s + t.totalAmount, 0);
      salesChart.push({
        date: dayStart.toISOString().split('T')[0],
        revenue,
      });
    }

    // 5 transaksi terbaru
    const recentTransactions = await this.prisma.transaction.findMany({
      take: 5,
      where: {
        outletId: outletId || undefined,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        cashier: { select: { name: true } },
        items: { include: { drug: { select: { name: true } } } },
      },
    });

    return {
      today: {
        revenue: todayRevenue,
        transactions: todayTransactions.length,
      },
      alerts: {
        pendingOrders,
        lowStockCount,
        nearExpiryCount,
      },
      salesChart,
      recentTransactions: recentTransactions.map((tx) => ({
        id: tx.id,
        cashierName: tx.cashier.name,
        totalAmount: tx.totalAmount,
        paymentMethod: tx.paymentMethod,
        itemCount: tx.items.reduce((s, i) => s + i.quantity, 0),
        createdAt: tx.createdAt,
        status: tx.status,
      })),
    };
  }
}