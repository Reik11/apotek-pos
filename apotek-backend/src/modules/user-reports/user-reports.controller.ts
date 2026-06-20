import {
  Controller, Get, Post, Patch,
  Body, Param, Query, UseGuards, Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UserReportsService } from './user-reports.service';

@Controller('user-reports')
@UseGuards(AuthGuard('jwt'))
export class UserReportsController {
  constructor(private userReportsService: UserReportsService) {}

  // Buat laporan baru
  @Post()
  create(@Request() req: any, @Body() body: { title: string; category: any; message: string }) {
    return this.userReportsService.create(req.user.id, body);
  }

  // Admin/Apoteker lihat semua laporan
  @Get()
  findAll(
    @Query('status') status?: string,
    @Query('category') category?: string,
  ) {
    return this.userReportsService.findAll(status, category);
  }

  // Pasien lihat laporan miliknya sendiri
  @Get('my')
  findMy(@Request() req: any) {
    return this.userReportsService.findByPatient(req.user.id);
  }

  // Lihat detail laporan
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.userReportsService.findOne(id);
  }

  // Balas laporan
  @Patch(':id/reply')
  reply(
    @Param('id') id: string,
    @Request() req: any,
    @Body() body: { replyMessage: string; status?: string },
  ) {
    return this.userReportsService.reply(id, req.user.id, body.replyMessage, body.status);
  }

  // Ubah status laporan saja
  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    return this.userReportsService.updateStatus(id, body.status);
  }
}
