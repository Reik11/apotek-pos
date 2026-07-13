import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { PrismaModule } from './modules/prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { DrugsModule } from './modules/drugs/drugs.module';
import { TransactionsModule } from './modules/transactions/transactions.module';
import { OrdersModule } from './modules/orders/orders.module';
import { ReportsModule } from './modules/reports/reports.module';
import { ExternalModule } from './modules/external/external.module';
import { UsersModule } from './modules/users/users.module';
import { AddressesModule } from './modules/addresses/addresses.module';
import { PrescriptionsModule } from './modules/prescriptions/prescriptions.module';
import { UserReportsModule } from './modules/user-reports/user-reports.module';
import { SuppliersModule } from './modules/suppliers/suppliers.module';
import { PurchaseOrdersModule } from './modules/purchase-orders/purchase-orders.module';
import { ShiftsModule } from './modules/shifts/shifts.module';
import { OutletsModule } from './modules/outlets/outlets.module';
import { ActivityLogsModule } from './modules/activity-logs/activity-logs.module';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { ActivityLogInterceptor } from './common/interceptors/activity-log.interceptor';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    DrugsModule,
    TransactionsModule,
    OrdersModule,
    ReportsModule,
    ExternalModule,
    UsersModule,
    AddressesModule,
    PrescriptionsModule,
    UserReportsModule,
    SuppliersModule,
    PurchaseOrdersModule,
    ShiftsModule,
    OutletsModule,
    ActivityLogsModule,
  ],
  providers: [
    {
      provide: APP_INTERCEPTOR,
      useClass: ActivityLogInterceptor,
    },
  ],
})
export class AppModule {}