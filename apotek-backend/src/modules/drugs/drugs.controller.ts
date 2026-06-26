import {
  Controller, Get, Post, Put, Patch, Delete,
  Body, Param, Query, UseGuards, Request, ForbiddenException,
} from '@nestjs/common';
import { DrugsService } from './drugs.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('drugs')
@UseGuards(AuthGuard('jwt'))
export class DrugsController {
  constructor(private drugsService: DrugsService) {}

  @Get()
  findAll(
    @Request() req: any,
    @Query('search') search?: string,
    @Query('category') category?: string,
    @Query('outletId') outletId?: string,
  ) {
    let targetOutletId = outletId;
    if (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'PASIEN') {
      targetOutletId = req.user.outletId;
    }
    return this.drugsService.findAll(search, category, targetOutletId);
  }

  @Get('expiring')
  getExpiring(@Request() req: any, @Query('days') days?: string) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'PASIEN') {
      targetOutletId = req.user.outletId;
    }
    return this.drugsService.getExpiringDrugs(days ? parseInt(days) : 90, targetOutletId);
  }

  @Get('low-stock')
  getLowStock(@Request() req: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'PASIEN') {
      targetOutletId = req.user.outletId;
    }
    return this.drugsService.getLowStockDrugs(targetOutletId);
  }

  @Get('alerts')
  getAlerts(@Request() req: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'PASIEN') {
      targetOutletId = req.user.outletId;
    }
    return this.drugsService.getAlerts(targetOutletId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.drugsService.findOne(id);
  }

  @Post()
  create(@Request() req: any, @Body() body: any) {
    const outletId = req.user.role === 'SUPER_ADMIN' ? body.outletId : req.user.outletId;
    return this.drugsService.create({
      ...body,
      outletId,
    });
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() body: any) {
    const drug = await this.drugsService.findOne(id);
    if (req.user.role !== 'SUPER_ADMIN') {
      if (!drug.outletId || drug.outletId !== req.user.outletId) {
        throw new ForbiddenException('Anda tidak memiliki akses untuk mengubah obat ini');
      }
    }
    return this.drugsService.update(id, body);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    const drug = await this.drugsService.findOne(id);
    if (req.user.role !== 'SUPER_ADMIN') {
      if (!drug.outletId || drug.outletId !== req.user.outletId) {
        throw new ForbiddenException('Anda tidak memiliki akses untuk menghapus obat ini');
      }
    }
    return this.drugsService.remove(id);
  }

  @Post('batch')
  addBatch(@Request() req: any, @Body() body: any) {
    const outletId = req.user.role === 'SUPER_ADMIN' ? body.outletId : req.user.outletId;
    return this.drugsService.addBatch({
      ...body,
      outletId,
    });
  }
}