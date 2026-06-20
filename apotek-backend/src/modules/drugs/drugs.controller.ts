import {
  Controller, Get, Post, Put, Patch, Delete,
  Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { DrugsService } from './drugs.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('drugs')
@UseGuards(AuthGuard('jwt'))
export class DrugsController {
  constructor(private drugsService: DrugsService) {}

  @Get()
  findAll(@Query('search') search?: string, @Query('category') category?: string) {
    return this.drugsService.findAll(search, category);
  }

  @Get('expiring')
  getExpiring(@Query('days') days?: string) {
    return this.drugsService.getExpiringDrugs(days ? parseInt(days) : 90);
  }

  @Get('low-stock')
  getLowStock() {
    return this.drugsService.getLowStockDrugs();
  }

  @Get('alerts')
  getAlerts() {
    return this.drugsService.getAlerts();
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
  addBatch(@Body() body: any) {
    return this.drugsService.addBatch(body);
  }
}