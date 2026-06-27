import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ShiftsService {
  constructor(private prisma: PrismaService) {}

  // Get active shift for a cashier
  async getActiveShift(userId: string) {
    return this.prisma.cashShift.findFirst({
      where: {
        cashierId: userId,
        status: 'OPEN',
      },
    });
  }

  // Open a new shift
  async openShift(userId: string, data: { startBalance: number; notes?: string }) {
    // Check if there is already an open shift for this user
    const active = await this.getActiveShift(userId);
    if (active) {
      throw new BadRequestException('Anda sudah memiliki shift kasir yang sedang aktif');
    }

    const cashier = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { outletId: true },
    });

    return this.prisma.cashShift.create({
      data: {
        cashierId: userId,
        startBalance: data.startBalance,
        status: 'OPEN',
        notes: data.notes,
        outletId: cashier?.outletId || null,
      },
    });
  }

  // Close an active shift
  async closeShift(userId: string, data: { endBalance: number; notes?: string }) {
    const active = await this.getActiveShift(userId);
    if (!active) {
      throw new BadRequestException('Anda tidak memiliki shift kasir yang sedang aktif');
    }

    // Get all transactions completed under this shift
    const transactions = await this.prisma.transaction.findMany({
      where: {
        shiftId: active.id,
        status: 'COMPLETED',
      },
    });

    // Calculate total transactions and cash sales in this shift
    const totalTransactions = transactions.length;
    const totalSales = transactions.reduce((sum, t) => sum + t.totalAmount, 0);

    const cashSales = transactions
      .filter((t) => t.paymentMethod === 'CASH')
      .reduce((sum, t) => sum + t.totalAmount, 0);

    // Calculate expected balance: startBalance + cashSales
    const expectedBalance = active.startBalance + cashSales;
    const difference = data.endBalance - expectedBalance;

    return this.prisma.cashShift.update({
      where: { id: active.id },
      data: {
        endTime: new Date(),
        endBalance: data.endBalance,
        expectedBalance,
        difference,
        totalSales,
        totalTransactions,
        status: 'CLOSED',
        notes: data.notes || active.notes,
      },
    });
  }

  // Get all cash shifts history
  async findAll(outletId?: string) {
    return this.prisma.cashShift.findMany({
      where: {
        outletId: outletId || undefined,
      },
      include: {
        cashier: { select: { id: true, name: true, email: true } },
        outlet: { select: { id: true, name: true } },
      },
      orderBy: { startTime: 'desc' },
    });
  }
}
