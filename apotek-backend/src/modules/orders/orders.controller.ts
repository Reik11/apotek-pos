import {
  Controller, Get, Post, Patch,
  Body, Param, Query, UseGuards, Request,
} from '@nestjs/common';
import { OrdersService } from './orders.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('orders')
@UseGuards(AuthGuard('jwt'))
export class OrdersController {
  constructor(private ordersService: OrdersService) {}

  // Pasien buat order baru
  @Post()
  create(@Request() req: any, @Body() body: any) {
    return this.ordersService.create({
      patientId: req.user.id,
      items: body.items,
      notes: body.notes,
      deliveryMethod: body.deliveryMethod,
      addressId: body.addressId,
      prescriptionId: body.prescriptionId,
      shippingFee: body.shippingFee,
      paymentMethod: body.paymentMethod,
    });
  }

  // Hitung biaya kirim
  @Get('shipping-fee')
  getShippingFee(@Query('city') city: string) {
    return this.ordersService.getShippingFee(city);
  }

  // Admin/apoteker lihat semua order
  @Get()
  findAll(@Query('status') status?: string) {
    return this.ordersService.findAll(status);
  }

  // Pasien lihat order miliknya
  @Get('my-orders')
  findMyOrders(@Request() req: any) {
    return this.ordersService.findByPatient(req.user.id);
  }

  // Cari order by kode (kasir scan QR)
  @Get('code/:orderCode')
  findByCode(@Param('orderCode') orderCode: string) {
    return this.ordersService.findByCode(orderCode);
  }

  // Kasir konfirmasi pengambilan
  @Post('pickup/:orderCode')
  confirmPickup(@Param('orderCode') orderCode: string) {
    return this.ordersService.confirmPickup(orderCode);
  }

  // Lihat detail order
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.ordersService.findOne(id);
  }

  // Update status order
  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() body: any) {
    return this.ordersService.updateStatus(id, body.status, body.paymentProof);
  }
}