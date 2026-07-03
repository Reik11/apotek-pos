import { Controller, Post, Param, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PaymentService } from './payment.service';

@Controller('payment')
export class PaymentController {
  constructor(private readonly paymentService: PaymentService) {}

  // 1. Minta token Snap untuk pembayaran (Hanya untuk pasien terautentikasi)
  @Post('charge/:orderId')
  @UseGuards(AuthGuard('jwt'))
  async charge(@Param('orderId') orderId: string) {
    return this.paymentService.createSnapTransaction(orderId);
  }

  // 2. Webhook Notifikasi dari Midtrans (Public endpoint - Tanpa AuthGuard)
  @Post('notification')
  @HttpCode(HttpStatus.OK)
  async handleNotification(@Body() body: any) {
    return this.paymentService.handleNotification(body);
  }
}
