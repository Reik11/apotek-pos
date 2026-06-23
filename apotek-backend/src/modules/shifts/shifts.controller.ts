import { Controller, Get, Post, Body, UseGuards, Request } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ShiftsService } from './shifts.service';

@Controller('shifts')
@UseGuards(AuthGuard('jwt'))
export class ShiftsController {
  constructor(private readonly shiftsService: ShiftsService) {}

  @Get('active')
  getActiveShift(@Request() req: any) {
    return this.shiftsService.getActiveShift(req.user.id);
  }

  @Post('open')
  openShift(@Request() req: any, @Body() body: { startBalance: number; notes?: string }) {
    return this.shiftsService.openShift(req.user.id, body);
  }

  @Post('close')
  closeShift(@Request() req: any, @Body() body: { endBalance: number; notes?: string }) {
    return this.shiftsService.closeShift(req.user.id, body);
  }
}
