import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SuppliersService {
  constructor(private prisma: PrismaService) {}

  async create(data: {
    name: string;
    phone?: string;
    email?: string;
    address?: string;
  }) {
    return this.prisma.supplier.create({
      data,
    });
  }

  async findAll() {
    return this.prisma.supplier.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const supplier = await this.prisma.supplier.findUnique({
      where: { id },
      include: {
        batches: true,
        purchaseOrders: true,
      },
    });
    if (!supplier) {
      throw new NotFoundException('Supplier tidak ditemukan');
    }
    return supplier;
  }

  async update(
    id: string,
    data: {
      name?: string;
      phone?: string;
      email?: string;
      address?: string;
    },
  ) {
    await this.findOne(id);
    return this.prisma.supplier.update({
      where: { id },
      data,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.supplier.delete({
      where: { id },
    });
  }
}
