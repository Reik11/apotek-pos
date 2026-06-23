import {
  Controller, Get, Post, Put, Patch, Delete,
  Body, Param, Query, UseGuards, Request,
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
  create(@Body() body: any) {
    return this.drugsService.create(body);
  }

 @Patch(':id')  // ← dari @Put menjadi @Patch
  update(@Param('id') id: string, @Body() body: any) {
    return this.drugsService.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
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