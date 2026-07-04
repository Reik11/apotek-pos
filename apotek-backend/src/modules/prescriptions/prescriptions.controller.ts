import {
  Controller, Get, Post, Patch,
  Body, Param, Query, UseGuards, Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PrescriptionsService } from './prescriptions.service';

@Controller('prescriptions')
@UseGuards(AuthGuard('jwt'))
export class PrescriptionsController {
  constructor(private prescriptionsService: PrescriptionsService) {}

  // Pasien upload resep (imageUrl dari Supabase Storage)
  @Post()
  create(@Request() req: any, @Body() body: any) {
    return this.prescriptionsService.create(req.user.id, {
      imageUrl: body.imageUrl,
      notes: body.notes,
    });
  }

  // Apoteker lihat semua resep (termasuk data medis pasien)
  @Get()
  findAll(@Query('status') status?: string) {
    return this.prescriptionsService.findAll(status);
  }

  // Pasien lihat resep miliknya
  @Get('my')
  findMy(@Request() req: any) {
    return this.prescriptionsService.findByPatient(req.user.id);
  }

  // Apoteker verifikasi/tolak resep (cara lama — tanpa membuat order)
  @Patch(':id/verify')
  verify(
    @Param('id') id: string,
    @Request() req: any,
    @Body() body: { status: 'VERIFIED' | 'REJECTED'; prescribedDrugs?: any },
  ) {
    return this.prescriptionsService.verify(id, req.user.id, body.status, body.prescribedDrugs);
  }

  // Apoteker verifikasi resep & otomatis buat tagihan Order untuk pasien
  @Post(':id/convert-to-order')
  convertToOrder(
    @Param('id') id: string,
    @Request() req: any,
    @Body() body: { items: { drugId: string; quantity: number; notes?: string }[] },
  ) {
    return this.prescriptionsService.convertToOrder(id, req.user.id, body.items);
  }
}
