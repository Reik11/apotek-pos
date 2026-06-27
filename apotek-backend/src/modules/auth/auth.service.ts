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

  // ============================================================
  // OTP: LUPA PASSWORD (Forgot Password)
  // ============================================================
  async sendOtp(email: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new NotFoundException('Email tidak terdaftar');

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5);

    this.otps.set(`forgot:${email}`, { code, expiresAt });
    return this.mailService.sendOtpEmail(email, code);
  }

  async resetPasswordWithOtp(email: string, otp: string, newPassword: string): Promise<any> {
    const key = `forgot:${email}`;
    const activeOtp = this.otps.get(key);
    if (!activeOtp) throw new BadRequestException('Kode OTP belum dikirim atau telah kedaluwarsa');
    if (activeOtp.code !== otp) throw new BadRequestException('Kode OTP yang Anda masukkan salah');
    if (new Date() > activeOtp.expiresAt) {
      this.otps.delete(key);
      throw new BadRequestException('Kode OTP telah kedaluwarsa. Silakan minta kode baru.');
    }

    this.otps.delete(key);
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({ where: { email }, data: { password: hashedPassword } });
    return { message: 'Kata sandi berhasil diperbarui' };
  }

  // ============================================================
  // OTP: PENDAFTARAN (Register)
  // ============================================================
  async sendRegisterOtp(email: string): Promise<boolean> {
    // Pastikan email belum terdaftar sebelum kirim OTP
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email sudah terdaftar. Silakan gunakan email lain.');

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5);

    this.otps.set(`register:${email}`, { code, expiresAt });
    return this.mailService.sendOtpEmail(email, code);
  }

  // ============================================================
  // OTP: GANTI PASSWORD (Change Password dari Profil)
  // ============================================================
  async sendChangePasswordOtp(email: string): Promise<boolean> {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5);

    this.otps.set(`change-password:${email}`, { code, expiresAt });
    return this.mailService.sendOtpEmail(email, code);
  }

  async verifyChangePasswordOtp(email: string, otp: string): Promise<void> {
    const key = `change-password:${email}`;
    const activeOtp = this.otps.get(key);
    if (!activeOtp) throw new BadRequestException('Kode OTP belum dikirim atau telah kedaluwarsa');
    if (activeOtp.code !== otp) throw new BadRequestException('Kode OTP salah');
    if (new Date() > activeOtp.expiresAt) {
      this.otps.delete(key);
      throw new BadRequestException('Kode OTP telah kedaluwarsa. Silakan minta kode baru.');
    }
    this.otps.delete(key);
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================
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

      let user = await this.prisma.user.findUnique({ where: { email } });
      if (!user) {
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

  // ============================================================
  // REGISTER (dengan verifikasi OTP)
  // ============================================================
  async register(name: string, email: string, password: string, otp: string, role?: any) {
    // Verifikasi OTP pendaftaran
    const key = `register:${email}`;
    const activeOtp = this.otps.get(key);
    if (!activeOtp) throw new BadRequestException('Kode OTP belum dikirim atau telah kedaluwarsa');
    if (activeOtp.code !== otp) throw new BadRequestException('Kode OTP salah');
    if (new Date() > activeOtp.expiresAt) {
      this.otps.delete(key);
      throw new BadRequestException('Kode OTP telah kedaluwarsa. Silakan minta kode baru.');
    }
    this.otps.delete(key);

    // Cek email sudah ada atau belum
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email sudah terdaftar');

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await this.prisma.user.create({
      data: { name, email, password: hashedPassword, role },
    });

    return this.generateToken(user);
  }

  // ============================================================
  // LOGIN
  // ============================================================
  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Email atau password salah');

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new UnauthorizedException('Email atau password salah');

    if (!user.isActive) throw new UnauthorizedException('Akun tidak aktif');

    return this.generateToken(user);
  }

  // ============================================================
  // GENERATE JWT TOKEN
  // ============================================================
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