import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor() {
    const host = process.env.SMTP_HOST;
    const port = process.env.SMTP_PORT;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (host && port && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port: parseInt(port, 10),
        secure: parseInt(port, 10) === 465, // true for 465, false for other ports
        auth: { user, pass },
      });
      this.logger.log('SMTP Transporter configured successfully');
    } else {
      this.logger.warn(
        'SMTP environment variables are not fully configured. Email sending will be simulated.',
      );
    }
  }

  async sendOtpEmail(to: string, otp: string): Promise<boolean> {
    const subject = 'Kode OTP Lupa Password - ApotekPOS';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #0d5c4a; text-align: center;">ApotekPOS</h2>
        <hr style="border: 0; border-top: 1px solid #e2e8f0;" />
        <p>Halo,</p>
        <p>Kami menerima permintaan untuk mereset kata sandi akun ApotekPOS Anda. Gunakan kode OTP di bawah ini untuk memverifikasi identitas Anda:</p>
        <div style="text-align: center; margin: 30px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #0d5c4a; background-color: #f1f5f9; padding: 12px 24px; border-radius: 8px; border: 1px dashed #cbd5e1;">
            ${otp}
          </span>
        </div>
        <p style="color: #64748b; font-size: 13px;">Kode OTP ini berlaku selama <strong>5 menit</strong>. Jika Anda tidak merasa meminta reset kata sandi, abaikan email ini.</p>
        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin-top: 30px;" />
        <p style="color: #94a3b8; font-size: 11px; text-align: center;">&copy; ${new Date().getFullYear()} ApotekPOS. Hak Cipta Dilindungi.</p>
      </div>
    `;

    // Log to console for easy local testing
    this.logger.log(`[SIMULASI EMAIL] OTP untuk ${to}: ${otp}`);

    if (!this.transporter) {
      this.logger.log('Simulated email sending successful (No SMTP configured)');
      return true;
    }

    try {
      await this.transporter.sendMail({
        from: `"ApotekPOS" <${process.env.SMTP_USER}>`,
        to,
        subject,
        html,
      });
      this.logger.log(`Email OTP sent successfully to ${to}`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to send email to ${to}: ${error.message}`);
      return false;
    }
  }
}
