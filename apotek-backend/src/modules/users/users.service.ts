import {
  Injectable, NotFoundException,
  UnauthorizedException, ConflictException, ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from '../auth/auth.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private authService: AuthService,
  ) {}

  async updateProfile(userId: string, name: string, email: string) {
    const existing = await this.prisma.user.findFirst({
      where: { email, NOT: { id: userId } },
    });
    if (existing) throw new ConflictException('Email sudah digunakan');

    return this.prisma.user.update({
      where: { id: userId },
      data: { name, email },
      select: { id: true, name: true, email: true, role: true },
    });
  }

  async getMedicalProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
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
    });
    if (!user) throw new NotFoundException('User tidak ditemukan');
    return user;
  }

  async updateMedicalProfile(userId: string, data: {
    birthDate?: string;
    gender?: string;
    weight?: number;
    height?: number;
    allergies?: string;
    chronicDiseases?: string;
    currentMedications?: string;
    isPregnant?: boolean;
    isBreastfeeding?: boolean;
    kidneyFunction?: string;
    liverFunction?: string;
  }) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        ...data,
        birthDate: data.birthDate ? new Date(data.birthDate) : undefined,
        medicalProfileUpdatedAt: new Date(),
      },
      select: {
        id: true,
        name: true,
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
    });
  }

  async changePassword(
    userId: string,
    email: string,
    currentPassword: string,
    newPassword: string,
    otp: string,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User tidak ditemukan');

    // Verifikasi password lama
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) throw new UnauthorizedException('Password saat ini salah');

    // Verifikasi OTP ganti password
    await this.authService.verifyChangePasswordOtp(email, otp);

    // Hash password baru
    const hashed = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { password: hashed },
    });

    return { message: 'Password berhasil diubah' };
  }

  // LIST SEMUA PENGGUNA (Admin only)
  async findAll(role?: string, outletId?: string) {
    const where: any = {};
    if (role !== 'SUPER_ADMIN' && outletId) {
      where.OR = [
        { outletId },
        { role: 'PASIEN' }
      ];
    }
    return this.prisma.user.findMany({
      where,
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        phone: true,
        isActive: true,
        shift: true,
        outletId: true,
        outlet: { select: { id: true, name: true } },
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // TAMBAH PENGGUNA BARU (Admin only)
  async create(data: {
    name: string;
    email: string;
    password: string;
    role: string;
    phone?: string;
    shift?: string;
    outletId?: string;
  }) {
    const existing = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existing) throw new ConflictException('Email sudah digunakan');
    const hashed = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: { ...data, password: hashed } as any,
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        shift: true,
        outletId: true,
        outlet: { select: { id: true, name: true } },
        createdAt: true,
      },
    });
  }

  // HAPUS PENGGUNA (Admin only)
  async remove(id: string, requesterId: string) {
    if (id === requesterId) throw new ForbiddenException('Tidak bisa menghapus akun sendiri');
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User tidak ditemukan');

    // 1. Hapus data aktivitas & data pendukung pasien
    await this.prisma.activityLog.deleteMany({ where: { userId: id } });
    await this.prisma.address.deleteMany({ where: { userId: id } });
    await this.prisma.ocrScan.deleteMany({ where: { userId: id } });
    await this.prisma.prescription.deleteMany({ where: { patientId: id } });
    await this.prisma.userReport.deleteMany({ where: { userId: id } });

    // 2. Hapus detail order & order pasien
    const orders = await this.prisma.order.findMany({ where: { patientId: id } });
    for (const order of orders) {
      await this.prisma.orderItem.deleteMany({ where: { orderId: order.id } });
    }
    await this.prisma.order.deleteMany({ where: { patientId: id } });

    // 3. Hapus detail transaksi & transaksi kasir
    const txs = await this.prisma.transaction.findMany({ where: { cashierId: id } });
    for (const tx of txs) {
      await this.prisma.transactionItem.deleteMany({ where: { transactionId: tx.id } });
    }
    await this.prisma.transaction.deleteMany({ where: { cashierId: id } });

    // 4. Hapus shift kasir
    await this.prisma.cashShift.deleteMany({ where: { cashierId: id } });

    // 5. Akhirnya hapus akun pengguna
    return this.prisma.user.delete({ where: { id } });
  }

  // UPDATE PENGGUNA (Admin only)
  async update(id: string, data: {
    name?: string;
    email?: string;
    role?: string;
    phone?: string;
    shift?: string;
    isActive?: boolean;
    outletId?: string;
  }) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User tidak ditemukan');

    if (data.email && data.email !== user.email) {
      const existing = await this.prisma.user.findFirst({
        where: { email: data.email, NOT: { id } },
      });
      if (existing) throw new ConflictException('Email sudah digunakan');
    }

    return this.prisma.user.update({
      where: { id },
      data: data as any,
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        phone: true,
        isActive: true,
        shift: true,
        outletId: true,
        outlet: { select: { id: true, name: true } },
        createdAt: true,
      },
    });
  }
}