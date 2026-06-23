import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OutletsService {
  constructor(private prisma: PrismaService) {}

  async create(data: {
    name: string;
    address: string;
    phone?: string;
    latitude?: number;
    longitude?: number;
  }) {
    return this.prisma.outlet.create({
      data,
    });
  }

  async findAll() {
    return this.prisma.outlet.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const outlet = await this.prisma.outlet.findUnique({
      where: { id },
    });
    if (!outlet) throw new NotFoundException('Outlet tidak ditemukan');
    return outlet;
  }

  async update(id: string, data: {
    name?: string;
    address?: string;
    phone?: string;
    latitude?: number;
    longitude?: number;
  }) {
    await this.findOne(id);
    return this.prisma.outlet.update({
      where: { id },
      data,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.outlet.delete({
      where: { id },
    });
  }
}
