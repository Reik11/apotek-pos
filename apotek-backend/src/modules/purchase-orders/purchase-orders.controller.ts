import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PurchaseOrdersService } from './purchase-orders.service';

@Controller('purchase-orders')
@UseGuards(AuthGuard('jwt'))
export class PurchaseOrdersController {
  constructor(private readonly purchaseOrdersService: PurchaseOrdersService) {}

  @Post()
  create(
    @Body()
    body: {
      supplierId: string;
      items: { drugId: string; quantity: number; price: number }[];
    },
  ) {
    return this.purchaseOrdersService.create(body);
  }

  @Get()
  findAll() {
    return this.purchaseOrdersService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.purchaseOrdersService.findOne(id);
  }

  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body()
    body: {
      status: 'PENDING' | 'ORDERED' | 'RECEIVED' | 'CANCELLED';
      receiveDetails?: {
        drugId: string;
        batchNumber: string;
        expiredDate: string;
      }[];
    },
  ) {
    return this.purchaseOrdersService.updateStatus(id, body);
  }
}
