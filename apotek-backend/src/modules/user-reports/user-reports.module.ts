import { Module } from '@nestjs/common';
import { UserReportsController } from './user-reports.controller';
import { UserReportsService } from './user-reports.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UserReportsController],
  providers: [UserReportsService],
  exports: [UserReportsService],
})
export class UserReportsModule {}
