import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import axios from 'axios';
import * as crypto from 'crypto';

@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);
  private readonly serverKey = process.env.MIDTRANS_SERVER_KEY;
  private readonly isProduction = process.env.MIDTRANS_IS_PRODUCTION === 'true';

  constructor(private prisma: PrismaService) {}

  private getAuthHeader(): string {
    if (!this.serverKey) {
      throw new BadRequestException('Midtrans Server Key is not configured.');
    }
    const token = Buffer.from(`${this.serverKey}:`).toString('base64');
    return `Basic ${token}`;
  }

  private getSnapUrl(): string {
    return this.isProduction
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
  }

  async createSnapTransaction(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        patient: { select: { name: true, email: true, phone: true } },
        items: { include: { drug: true } },
      },
    });

    if (!order) {
      throw new NotFoundException('Pesanan tidak ditemukan');
    }

    // If snap token already exists, just return it to avoid recreating transaction in Midtrans
    if (order.snapToken && order.snapUrl) {
      return {
        token: order.snapToken,
        redirect_url: order.snapUrl,
      };
    }

    const snapUrl = this.getSnapUrl();
    const authHeader = this.getAuthHeader();

    const itemDetails = order.items.map((item) => ({
      id: item.drugId,
      price: item.price,
      quantity: item.quantity,
      name: item.drug.name.substring(0, 50),
    }));

    // Add shipping fee if delivery
    if (order.shippingFee > 0) {
      itemDetails.push({
        id: 'SHIPPING_FEE',
        price: order.shippingFee,
        quantity: 1,
        name: 'Ongkos Kirim',
      });
    }

    const payload = {
      transaction_details: {
        order_id: order.orderCode,
        gross_amount: order.totalAmount,
      },
      customer_details: {
        first_name: order.patient.name,
        email: order.patient.email,
        phone: order.patient.phone || '',
      },
      item_details: itemDetails,
    };

    try {
      this.logger.log(`Creating Midtrans Snap transaction for order ${order.orderCode}...`);
      const response = await axios.post(snapUrl, payload, {
        headers: {
          Authorization: authHeader,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      });

      const { token, redirect_url } = response.data;

      // Save token to database
      await this.prisma.order.update({
        where: { id: orderId },
        data: {
          snapToken: token,
          snapUrl: redirect_url,
          paymentMethod: 'MIDTRANS',
        },
      });

      this.logger.log(`Midtrans Snap token created: ${token}`);
      return { token, redirect_url };

    } catch (error: any) {
      const errorMsg = error.response?.data?.error_messages?.join(', ') || error.message;
      this.logger.error(`Failed to create Midtrans Snap transaction: ${errorMsg}`);
      throw new BadRequestException(`Gagal memproses pembayaran ke Midtrans: ${errorMsg}`);
    }
  }

  async handleNotification(payload: any) {
    this.logger.log(`Received Midtrans notification for order: ${payload.order_id}`);

    const {
      order_id,
      status_code,
      gross_amount,
      signature_key,
      transaction_status,
      fraud_status,
    } = payload;

    // 1. Verify Signature Key: SHA512(order_id + status_code + gross_amount + ServerKey)
    if (!this.serverKey) {
      this.logger.error('Midtrans Server Key is not configured. Webhook ignored.');
      return { status: 'error', message: 'Server Key not configured' };
    }

    const rawSignature = `${order_id}${status_code}${gross_amount}${this.serverKey}`;
    const calculatedSignature = crypto
      .createHash('sha512')
      .update(rawSignature)
      .digest('hex');

    if (calculatedSignature !== signature_key) {
      this.logger.warn(`Signature verification failed for order ${order_id}!`);
      throw new BadRequestException('Signature key tidak valid');
    }

    // Find the corresponding order
    const order = await this.prisma.order.findUnique({
      where: { orderCode: order_id },
    });

    if (!order) {
      this.logger.warn(`Order with code ${order_id} not found in database.`);
      return { status: 'error', message: 'Order not found' };
    }

    let nextStatus: any = order.status;

    // 2. Map Midtrans transaction status to Order status
    if (transaction_status === 'capture') {
      if (fraud_status === 'challenge') {
        nextStatus = 'PENDING'; // Need manual check
      } else if (fraud_status === 'accept') {
        nextStatus = 'CONFIRMED';
      }
    } else if (transaction_status === 'settlement') {
      nextStatus = 'CONFIRMED';
    } else if (transaction_status === 'pending') {
      nextStatus = 'PENDING';
    } else if (
      transaction_status === 'deny' ||
      transaction_status === 'expire' ||
      transaction_status === 'cancel'
    ) {
      nextStatus = 'CANCELLED';
    }

    // Update order status in database
    await this.prisma.order.update({
      where: { id: order.id },
      data: { status: nextStatus },
    });

    this.logger.log(`Order ${order_id} status updated to: ${nextStatus}`);
    return { status: 'success', nextStatus };
  }
}
