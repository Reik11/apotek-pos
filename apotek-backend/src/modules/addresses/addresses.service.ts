import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AddressesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, data: {
    label?: string;
    recipientName: string;
    phone: string;
    street: string;
    city: string;
    province: string;
    postalCode: string;
    isDefault?: boolean;
  }) {
    // If isDefault, unset all others first
    if (data.isDefault) {
      await this.prisma.address.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }
    return this.prisma.address.create({
      data: { userId, ...data },
    });
  }

  async findAll(userId: string) {
    return this.prisma.address.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async update(id: string, userId: string, data: any) {
    const address = await this.prisma.address.findUnique({ where: { id } });
    if (!address) throw new NotFoundException('Alamat tidak ditemukan');
    if (address.userId !== userId) throw new ForbiddenException();
    if (data.isDefault) {
      await this.prisma.address.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }
    return this.prisma.address.update({ where: { id }, data });
  }

  async remove(id: string, userId: string) {
    const address = await this.prisma.address.findUnique({ where: { id } });
    if (!address) throw new NotFoundException('Alamat tidak ditemukan');
    if (address.userId !== userId) throw new ForbiddenException();
    return this.prisma.address.delete({ where: { id } });
  }
}
