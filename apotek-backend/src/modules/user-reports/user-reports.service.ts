import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UserReportsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, data: { title: string; category: any; message: string }) {
    return this.prisma.userReport.create({
      data: {
        userId,
        title: data.title,
        category: data.category,
        message: data.message,
      },
      include: {
        user: { select: { id: true, name: true, email: true } },
      },
    });
  }

  async findAll(status?: any, category?: any) {
    return this.prisma.userReport.findMany({
      where: {
        status: status ? status : undefined,
        category: category ? category : undefined,
      },
      include: {
        user: { select: { id: true, name: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findByPatient(userId: string) {
    return this.prisma.userReport.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const report = await this.prisma.userReport.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, name: true, email: true } },
      },
    });
    if (!report) {
      throw new NotFoundException('Laporan tidak ditemukan');
    }
    return report;
  }

  async reply(id: string, repliedBy: string, replyMessage: string, status?: any) {
    const report = await this.prisma.userReport.findUnique({ where: { id } });
    if (!report) {
      throw new NotFoundException('Laporan tidak ditemukan');
    }
    return this.prisma.userReport.update({
      where: { id },
      data: {
        adminReply: replyMessage,
        repliedBy,
        repliedAt: new Date(),
        status: status || 'RESOLVED',
      },
      include: {
        user: { select: { id: true, name: true, email: true } },
      },
    });
  }

  async updateStatus(id: string, status: any) {
    const report = await this.prisma.userReport.findUnique({ where: { id } });
    if (!report) {
      throw new NotFoundException('Laporan tidak ditemukan');
    }
    return this.prisma.userReport.update({
      where: { id },
      data: { status },
    });
  }
}
