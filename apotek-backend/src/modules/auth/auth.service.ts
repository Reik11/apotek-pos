import { Injectable, UnauthorizedException, ConflictException, BadRequestException, NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from './mail.service';
import { OAuth2Client } from 'google-auth-library';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private mailService: MailService,
  ) {}

  // In-memory OTP storage
  private otps = new Map<string, { code: string; expiresAt: Date }>();

  // SEND OTP TO EMAIL
  async sendOtp(email: string): Promise<boolean> {
    // Check if email exists in database
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new NotFoundException('Email tidak terdaftar');

    // Generate 6 digit numeric code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5); // 5 minutes validity

    this.otps.set(email, { code, expiresAt });

    // Send email
    return this.mailService.sendOtpEmail(email, code);
  }

  // RESET PASSWORD WITH OTP
  async resetPasswordWithOtp(email: string, otp: string, newPassword: string): Promise<any> {
    const activeOtp = this.otps.get(email);
    if (!activeOtp) {
      throw new BadRequestException('Kode OTP belum dikirim atau telah kedaluwarsa');
    }

    if (activeOtp.code !== otp) {
      throw new BadRequestException('Kode OTP yang Anda masukkan salah');
    }

    if (new Date() > activeOtp.expiresAt) {
      this.otps.delete(email);
      throw new BadRequestException('Kode OTP telah kedaluwarsa. Silakan minta kode baru.');
    }

    // OTP is valid, clear it
    this.otps.delete(email);

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update user password
    await this.prisma.user.update({
      where: { email },
      data: { password: hashedPassword },
    });

    return { message: 'Kata sandi berhasil diperbarui' };
  }

  // GOOGLE LOGIN
  async googleLogin(idToken: string): Promise<any> {
    try {
      const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
      const ticket = await client.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });

      const payload = ticket.getPayload();
      if (!payload || !payload.email) {
        throw new BadRequestException('ID Token Google tidak valid atau email tidak ditemukan');
      }

      const { email, name, picture } = payload;

      // Find or create user
      let user = await this.prisma.user.findUnique({ where: { email } });
      if (!user) {
        // Register new user with random password and default role PASIEN
        const randomPassword = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
        const hashedPassword = await bcrypt.hash(randomPassword, 10);

        user = await this.prisma.user.create({
          data: {
            name: name || 'Pengguna Google',
            email,
            password: hashedPassword,
            role: 'PASIEN',
            avatarUrl: picture || null,
          },
        });
      } else {
        // Update avatar if available and not set
        if (picture && !user.avatarUrl) {
          await this.prisma.user.update({
            where: { id: user.id },
            data: { avatarUrl: picture },
          });
        }
      }

      if (!user.isActive) {
        throw new UnauthorizedException('Akun tidak aktif');
      }

      return this.generateToken(user);
    } catch (error) {
      if (error instanceof UnauthorizedException || error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Gagal masuk menggunakan Google: ${error.message}`);
    }
  }

  // REGISTER
  async register(name: string, email: string, password: string, role?: any) {
    // Cek email sudah ada atau belum
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email sudah terdaftar');

    // Enkripsi password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Simpan user baru
    const user = await this.prisma.user.create({
      data: { name, email, password: hashedPassword, role },
    });

    return this.generateToken(user);
  }

  // LOGIN
  async login(email: string, password: string) {
    // Cari user by email
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Email atau password salah');

    // Cek password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new UnauthorizedException('Email atau password salah');

    // Cek user aktif
    if (!user.isActive) throw new UnauthorizedException('Akun tidak aktif');

    return this.generateToken(user);
  }

  // GENERATE JWT TOKEN
  private generateToken(user: any) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      accessToken: this.jwtService.sign(payload),
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        outletId: user.outletId,
      },
    };
  }

  // VALIDASI USER (dipakai JwtStrategy)
  async validateUser(userId: string) {
    return this.prisma.user.findUnique({ where: { id: userId } });
  }
}