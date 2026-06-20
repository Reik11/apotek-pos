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

  // ==== ADMIN ENDPOINTS ====

  @Get()
  findAll() {
    return this.usersService.findAll();
  }

  @Post()
  create(@Body() body: any) {
    return this.usersService.create({
      name: body.name,
      email: body.email,
      password: body.password,
      role: body.role,
      phone: body.phone,
    });
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req: any) {
    return this.usersService.remove(id, req.user.id);
  }

  // ==== USER SELF ENDPOINTS ====

  @Put('profile')
  updateProfile(@Request() req: any, @Body() body: any) {
    return this.usersService.updateProfile(req.user.id, body.name, body.email);
  }

  @Put('change-password')
  changePassword(@Request() req: any, @Body() body: any) {
    return this.usersService.changePassword(
      req.user.id,
      body.currentPassword,
      body.newPassword,
    );
  }
}