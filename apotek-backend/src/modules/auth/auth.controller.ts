import {
  Controller, Post, Body,
} from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  register(@Body() body: any) {
    return this.authService.register(
      body.name, body.email, body.password, body.role
    );
  }

  @Post('login')
  login(@Body() body: any) {
    return this.authService.login(body.email, body.password);
  }

  @Post('google')
  googleLogin(@Body() body: { idToken: string }) {
    return this.authService.googleLogin(body.idToken);
  }

  @Post('forgot-password/request')
  forgotPasswordRequest(@Body() body: { email: string }) {
    return this.authService.sendOtp(body.email);
  }

  @Post('forgot-password/reset')
  forgotPasswordReset(@Body() body: { email: string; otp: string; newPassword: any }) {
    return this.authService.resetPasswordWithOtp(body.email, body.otp, body.newPassword);
  }
}