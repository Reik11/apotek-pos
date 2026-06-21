import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PrescriptionsService {
  constructor(private prisma: PrismaService) {}

  async create(patientId: string, data: { imageUrl: string; notes?: string }) {
    return this.prisma.prescription.create({
      data: { patientId, ...data },
      include: { patient: { select: { id: true, name: true, email: true } } },
    });
  }

  async findAll(status?: string) {
    return this.prisma.prescription.findMany({
      where: status ? { status: status as any } : undefined,
      include: {
        patient: { select: { id: true, name: true, email: true } },
        orders: { select: { id: true, orderCode: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findByPatient(patientId: string) {
    return this.prisma.prescription.findMany({
      where: { patientId },
      include: {
        orders: { select: { id: true, orderCode: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async verify(id: string, apotekerId: string, status: 'VERIFIED' | 'REJECTED', prescribedDrugs?: any) {
    const prescription = await this.prisma.prescription.findUnique({ where: { id } });
    if (!prescription) throw new NotFoundException('Resep tidak ditemukan');
    return this.prisma.prescription.update({
      where: { id },
      data: {
        status,
        verifiedBy: apotekerId,
        verifiedAt: new Date(),
        prescribedDrugs: prescribedDrugs || undefined,
      },
    });
  }
}
