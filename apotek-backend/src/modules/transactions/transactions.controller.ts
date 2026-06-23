import {
  Controller, Get, Post, Body,
  Param, Query, UseGuards, Request, Patch,
} from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('transactions')
@UseGuards(AuthGuard('jwt'))
export class TransactionsController {
  constructor(private transactionsService: TransactionsService) {}

  @Post()
  create(@Request() req: any, @Body() body: any) {
    return this.transactionsService.create({
      cashierId: req.user.id,
      items: body.items,
      paymentMethod: body.paymentMethod,
      amountPaid: body.amountPaid,
      discountType: body.discountType,
      discountValue: body.discountValue,
      notes: body.notes,
    });
  }

  @Get()
  findAll(
    @Request() req: any,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('outletId') outletId?: string,
  ) {
    let targetOutletId = outletId;
    if (req.user.role !== 'SUPER_ADMIN') {
      targetOutletId = req.user.outletId;
    }
    return this.transactionsService.findAll(startDate, endDate, targetOutletId);
  }

  @Get('summary/today')
  getDailySummary(@Request() req: any) {
    let targetOutletId = undefined;
    if (req.user.role !== 'SUPER_ADMIN') {
      targetOutletId = req.user.outletId;
    }
    return this.transactionsService.getDailySummary(targetOutletId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.transactionsService.findOne(id);
  }

  @Patch(':id/void')
  voidTransaction(@Param('id') id: string) {
    return this.transactionsService.voidTransaction(id);
  }
}