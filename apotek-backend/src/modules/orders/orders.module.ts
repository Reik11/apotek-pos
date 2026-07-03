import { Module } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { OrdersController } from './orders.controller';
import { PaymentService } from './payment.service';
import { PaymentController } from './payment.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [OrdersService, PaymentService],
  controllers: [OrdersController, PaymentController],
  exports: [OrdersService, PaymentService],
})
export class OrdersModule {}