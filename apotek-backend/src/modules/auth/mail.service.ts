import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  
  // Resend Config
  private readonly resendApiKey = process.env.RESEND_API_KEY;
  private readonly resendFromEmail = process.env.RESEND_FROM_EMAIL || 'onboarding@resend.dev';

  // Brevo API Config (Pilihan B - HTTPS Port 443)
  private readonly brevoApiKey = process.env.BREVO_API_KEY;
  private readonly brevoSenderEmail = process.env.BREVO_SENDER_EMAIL || 'lexitkuromori@gmail.com';

  // SMTP Config (Gmail/Brevo SMTP)
  private transporter: nodemailer.Transporter | null = null;
  private readonly smtpUser = process.env.SMTP_USE || process.env.SMTP_USER;

  constructor() {
    if (this.resendApiKey) {
      this.logger.log('📧 Mail Service: Using Resend.com API (HTTPS)');
    } else if (this.brevoApiKey) {
      this.logger.log(`📧 Mail Service: Using Brevo.com API (HTTPS, Sender: ${this.brevoSenderEmail})`);
    } else {
      const host = process.env.SMTP_HOST;
      const port = process.env.SMTP_PORT;
      const pass = process.env.SMTP_PASS;

      if (host && port && this.smtpUser && pass) {
        this.transporter = nodemailer.createTransport({
          host,
          port: parseInt(port, 10),
          secure: parseInt(port, 10) === 465,
          auth: { user: this.smtpUser, pass },
        });
        this.logger.log('📧 Mail Service: Using SMTP Transporter');
      } else {
        this.logger.warn(
          '📧 Mail Service: No keys found. Email sending will be simulated in console.',
        );
      }
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

    this.logger.log(`[OTP SERVICE] Target: ${to} | Code: ${otp}`);

    // KASUS 1: Menggunakan Resend.com API (HTTPS)
    if (this.resendApiKey) {
      try {
        const response = await axios.post(
          'https://api.resend.com/emails',
          {
            from: `ApotekPOS <${this.resendFromEmail}>`,
            to,
            subject,
            html,
          },
          {
            headers: {
              Authorization: `Bearer ${this.resendApiKey}`,
              'Content-Type': 'application/json',
            },
          },
        );
        if (response.status === 200 || response.status === 201) {
          this.logger.log(`OTP sent to ${to} via Resend.com`);
          return true;
        }
        return false;
      } catch (error: any) {
        this.logger.error(`Resend failed: ${error.response?.data?.message || error.message}`);
        return false;
      }
    }

    // KASUS 2: Menggunakan Brevo API (HTTPS - Pilihan B)
    if (this.brevoApiKey) {
      try {
        const response = await axios.post(
          'https://api.brevo.com/v3/smtp/email',
          {
            sender: { name: 'ApotekPOS', email: this.brevoSenderEmail },
            to: [{ email: to }],
            subject,
            htmlContent: html,
          },
          {
            headers: {
              'api-key': this.brevoApiKey,
              'Content-Type': 'application/json',
              Accept: 'application/json',
            },
          },
        );
        if (response.status === 200 || response.status === 201) {
          this.logger.log(`OTP sent to ${to} via Brevo.com API`);
          return true;
        }
        return false;
      } catch (error: any) {
        this.logger.error(`Brevo API failed: ${error.response?.data?.message || error.message}`);
        return false;
      }
    }

    // KASUS 3: Menggunakan SMTP
    if (this.transporter) {
      try {
        await this.transporter.sendMail({
          from: `"ApotekPOS" <${this.smtpUser}>`,
          to,
          subject,
          html,
        });
        this.logger.log(`OTP sent to ${to} via SMTP`);
        return true;
      } catch (error: any) {
        this.logger.error(`SMTP failed: ${error.message}`);
        return false;
      }
    }

    // KASUS 4: Simulasi Console
    this.logger.log(`[SIMULATION SUCCESS] OTP printed in console.`);
    return true;
  }
}
