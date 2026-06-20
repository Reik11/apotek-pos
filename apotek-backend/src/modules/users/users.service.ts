import {
  Injectable, NotFoundException,
  UnauthorizedException, ConflictException, ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async updateProfile(userId: string, name: string, email: string) {
    // Cek email sudah dipakai user lain
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

  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) throw new NotFoundException('User tidak ditemukan');

    // Verifikasi password lama
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      throw new UnauthorizedException('Password saat ini salah');
    }

    // Hash password baru
    const hashed = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { password: hashed },
    });

    return { message: 'Password berhasil diubah' };
  }

  // LIST SEMUA PENGGUNA (Admin only)
  async findAll() {
    return this.prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        phone: true,
        isActive: true,
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
  }) {
    const existing = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existing) throw new ConflictException('Email sudah digunakan');
    const hashed = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: { ...data, password: hashed } as any,
      select: { id: true, name: true, email: true, role: true, createdAt: true },
    });
  }

  // HAPUS PENGGUNA (Admin only)
  async remove(id: string, requesterId: string) {
    if (id === requesterId) throw new ForbiddenException('Tidak bisa menghapus akun sendiri');
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User tidak ditemukan');
    return this.prisma.user.delete({ where: { id } });
  }
}