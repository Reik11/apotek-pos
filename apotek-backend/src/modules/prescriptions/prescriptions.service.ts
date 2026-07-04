import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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

  async createWithFile(patientId: string, file: any, notes?: string) {
    if (!file) throw new BadRequestException('File gambar resep tidak boleh kosong.');
    
    // Pastikan folder upload ada
    const path = require('path');
    const fs = require('fs');
    const uploadsDir = path.join(__dirname, '..', '..', '..', 'uploads', 'prescriptions');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const fileExt = path.extname(file.originalname) || '.jpg';
    const filename = `rx_${Date.now()}_${Math.random().toString(36).substring(2, 7)}${fileExt}`;
    const filePath = path.join(uploadsDir, filename);

    // Tulis file secara sinkron
    fs.writeFileSync(filePath, file.buffer);

    // Base URL dinamis
    const baseUrl = process.env.BASE_URL || 'http://localhost:3000';
    const imageUrl = `${baseUrl}/uploads/prescriptions/${filename}`;

    return this.prisma.prescription.create({
      data: {
        patientId,
        imageUrl,
        notes: notes || null,
      },
      include: { patient: { select: { id: true, name: true, email: true } } },
    });
  }


  async findAll(status?: string) {
    return this.prisma.prescription.findMany({
      where: status ? { status: status as any } : undefined,
      include: {
        patient: {
          select: {
            id: true,
            name: true,
            email: true,
            birthDate: true,
            gender: true,
            weight: true,
            height: true,
            allergies: true,
            chronicDiseases: true,
            currentMedications: true,
            isPregnant: true,
            isBreastfeeding: true,
            kidneyFunction: true,
            liverFunction: true,
            medicalProfileUpdatedAt: true,
          },
        },
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

  /**
   * Konversi resep yang sudah diverifikasi apoteker menjadi Order+OrderItem baru
   * sekaligus menyimpan aturan pakai (Signa) per obat.
   */
  async convertToOrder(
    prescriptionId: string,
    apotekerId: string,
    items: { drugId: string; quantity: number; notes?: string }[],
  ) {
    // 1. Ambil & validasi resep
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
    });
    if (!prescription) throw new NotFoundException('Resep tidak ditemukan');
    if (prescription.status !== 'PENDING') {
      throw new BadRequestException('Resep ini sudah pernah diproses');
    }

    // 2. Hitung total harga dan siapkan data item
    let totalAmount = 0;
    const orderItemsData: any[] = [];

    for (const item of items) {
      const drug = await this.prisma.drug.findUnique({ where: { id: item.drugId } });
      if (!drug) throw new NotFoundException(`Obat dengan ID ${item.drugId} tidak ditemukan`);

      const subtotal = drug.sellPrice * item.quantity;
      totalAmount += subtotal;

      orderItemsData.push({
        drugId: item.drugId,
        quantity: item.quantity,
        price: drug.sellPrice,
        subtotal,
        notes: item.notes ?? null, // Aturan pakai (Signa) dari apoteker
      });
    }

    const orderCode = `APT-${Date.now()}-${Math.random()
      .toString(36)
      .substring(2, 6)
      .toUpperCase()}`;

    // 3. Jalankan dalam satu Prisma transaction agar atomik
    return this.prisma.$transaction(async (tx) => {
      // A. Update status resep menjadi VERIFIED
      await tx.prescription.update({
        where: { id: prescriptionId },
        data: {
          status: 'VERIFIED',
          verifiedBy: apotekerId,
          verifiedAt: new Date(),
        },
      });

      // B. Buat Order baru bertipe PICKUP (obat resep harus diambil langsung)
      return tx.order.create({
        data: {
          patientId: prescription.patientId,
          prescriptionId,
          totalAmount,
          orderCode,
          deliveryMethod: 'PICKUP',
          paymentMethod: 'TRANSFER',
          items: {
            create: orderItemsData,
          },
        },
        include: {
          items: { include: { drug: true } },
          prescription: { select: { id: true, imageUrl: true, notes: true } },
        },
      });
    });
  }
}
