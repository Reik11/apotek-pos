import {
  Controller, Get, Post, Delete,
  Body, Param, UseGuards, Request,
  Put,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(AuthGuard('jwt'))
export class UsersController {
  constructor(private usersService: UsersService) {}

  // ==== USER SELF ENDPOINTS ====

  @Put('profile')
  updateProfile(@Request() req: any, @Body() body: any) {
    return this.usersService.updateProfile(req.user.id, body.name, body.email);
  }

  @Get('medical-profile')
  getMedicalProfile(@Request() req: any) {
    return this.usersService.getMedicalProfile(req.user.id);
  }

  @Put('medical-profile')
  updateMedicalProfile(@Request() req: any, @Body() body: any) {
    return this.usersService.updateMedicalProfile(req.user.id, {
      birthDate: body.birthDate,
      gender: body.gender,
      weight: body.weight,
      height: body.height,
      allergies: body.allergies,
      chronicDiseases: body.chronicDiseases,
      currentMedications: body.currentMedications,
      isPregnant: body.isPregnant,
      isBreastfeeding: body.isBreastfeeding,
      kidneyFunction: body.kidneyFunction,
      liverFunction: body.liverFunction,
    });
  }

  @Put('change-password')
  changePassword(@Request() req: any, @Body() body: any) {
    return this.usersService.changePassword(
      req.user.id,
      req.user.email,
      body.currentPassword,
      body.newPassword,
      body.otp,
    );
  }

  // ==== ADMIN ENDPOINTS ====

  @Get()
  findAll(@Request() req: any) {
    return this.usersService.findAll(req.user.role, req.user.outletId);
  }

  @Post()
  create(@Request() req: any, @Body() body: any) {
    const outletId = req.user.role === 'SUPER_ADMIN' ? body.outletId : req.user.outletId;
    return this.usersService.create({
      name: body.name,
      email: body.email,
      password: body.password,
      role: body.role,
      phone: body.phone,
      shift: body.shift,
      outletId,
    });
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req: any) {
    return this.usersService.remove(id, req.user.id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Request() req: any, @Body() body: any) {
    const outletId = req.user.role === 'SUPER_ADMIN' ? body.outletId : req.user.outletId;
    return this.usersService.update(id, {
      name: body.name,
      email: body.email,
      role: body.role,
      phone: body.phone,
      shift: body.shift,
      isActive: body.isActive,
      outletId,
    });
  }
}