import { Controller, Get, Query, UseGuards, Request } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('reports')
@UseGuards(AuthGuard('jwt'))
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get('dashboard')
  getDashboard(@Request() req: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN') {
      targetOutletId = req.user.outletId;
    }
    return this.reportsService.getDashboardSummary(targetOutletId);
  }

  @Get('sales')
  getSales(@Request() req: any, @Query('period') period: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN') {
      targetOutletId = req.user.outletId;
    }
    return this.reportsService.getSalesReport(period || 'daily', targetOutletId);
  }

  @Get('inventory')
  getInventory(@Request() req: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN') {
      targetOutletId = req.user.outletId;
    }
    return this.reportsService.getInventoryReport(targetOutletId);
  }

  @Get('expiry')
  getExpiry(@Request() req: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN') {
      targetOutletId = req.user.outletId;
    }
    return this.reportsService.getExpiryReport(targetOutletId);
  }
}