import {
  Controller, Get, Post, Body,
  Param, Query, UseGuards, Request,
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
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.transactionsService.findAll(startDate, endDate);
  }

  @Get('summary/today')
  getDailySummary() {
    return this.transactionsService.getDailySummary();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.transactionsService.findOne(id);
  }
}