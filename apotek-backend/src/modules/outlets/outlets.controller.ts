import {
  Controller, Get, Post, Put, Delete,
  Body, Param, UseGuards, Request, ForbiddenException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { OutletsService } from './outlets.service';

@Controller('outlets')
@UseGuards(AuthGuard('jwt'))
export class OutletsController {
  constructor(private outletsService: OutletsService) {}

  @Get()
  findAll() {
    return this.outletsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.outletsService.findOne(id);
  }

  @Post()
  create(@Request() req: any, @Body() body: any) {
    if (req.user.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Hanya Super Admin yang dapat menambahkan outlet');
    }
    return this.outletsService.create({
      name: body.name,
      address: body.address,
      phone: body.phone,
      latitude: body.latitude ? parseFloat(body.latitude) : undefined,
      longitude: body.longitude ? parseFloat(body.longitude) : undefined,
    });
  }

  @Put(':id')
  update(@Param('id') id: string, @Request() req: any, @Body() body: any) {
    if (req.user.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Hanya Super Admin yang dapat mengedit outlet');
    }
    return this.outletsService.update(id, {
      name: body.name,
      address: body.address,
      phone: body.phone,
      latitude: body.latitude ? parseFloat(body.latitude) : undefined,
      longitude: body.longitude ? parseFloat(body.longitude) : undefined,
    });
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req: any) {
    if (req.user.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Hanya Super Admin yang dapat menghapus outlet');
    }
    return this.outletsService.remove(id);
  }
}
