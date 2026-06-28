import {
  Controller, Post, Get, Body, UseGuards, Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Get('test-smtp')
  testSmtp() {
    return this.authService.testSmtpConnection();
  }

  // ===== PENDAFTARAN =====
  @Post('register/request-otp')
  registerRequestOtp(@Body() body: { email: string }) {
    return this.authService.sendRegisterOtp(body.email);
  }

  @Post('register')
  register(@Body() body: any) {
    return this.authService.register(
      body.name, body.email, body.password, body.otp, body.role
    );
  }

  // ===== LOGIN =====
  @Post('login')
  login(@Body() body: any) {
    return this.authService.login(body.email, body.password);
  }

  // ===== GOOGLE LOGIN =====
  @Post('google')
  googleLogin(@Body() body: { idToken: string }) {
    return this.authService.googleLogin(body.idToken);
  }

  // ===== LUPA PASSWORD =====
  @Post('forgot-password/request')
  forgotPasswordRequest(@Body() body: { email: string }) {
    return this.authService.sendOtp(body.email);
  }

  @Post('forgot-password/reset')
  forgotPasswordReset(@Body() body: { email: string; otp: string; newPassword: any }) {
    return this.authService.resetPasswordWithOtp(body.email, body.otp, body.newPassword);
  }

  // ===== GANTI PASSWORD (dari Profil, perlu login) =====
  @Post('change-password/request-otp')
  @UseGuards(AuthGuard('jwt'))
  changePasswordRequestOtp(@Request() req: any) {
    return this.authService.sendChangePasswordOtp(req.user.email);
  }
}