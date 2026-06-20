import {
  Controller, Get, Post, Patch, Delete,
  Body, Param, UseGuards, Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AddressesService } from './addresses.service';

@Controller('addresses')
@UseGuards(AuthGuard('jwt'))
export class AddressesController {
  constructor(private addressesService: AddressesService) {}

  @Post()
  create(@Request() req: any, @Body() body: any) {
    return this.addressesService.create(req.user.id, body);
  }

  @Get('my')
  findAll(@Request() req: any) {
    return this.addressesService.findAll(req.user.id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Request() req: any, @Body() body: any) {
    return this.addressesService.update(id, req.user.id, body);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req: any) {
    return this.addressesService.remove(id, req.user.id);
  }
}
