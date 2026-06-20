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

  // Apoteker lihat semua resep
  @Get()
  findAll(@Query('status') status?: string) {
    return this.prescriptionsService.findAll(status);
  }

  // Pasien lihat resep miliknya
  @Get('my')
  findMy(@Request() req: any) {
    return this.prescriptionsService.findByPatient(req.user.id);
  }

  // Apoteker verifikasi/tolak resep
  @Patch(':id/verify')
  verify(
    @Param('id') id: string,
    @Request() req: any,
    @Body() body: { status: 'VERIFIED' | 'REJECTED'; prescribedDrugs?: any },
  ) {
    return this.prescriptionsService.verify(id, req.user.id, body.status, body.prescribedDrugs);
  }
}
