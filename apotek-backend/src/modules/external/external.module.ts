import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { RxNormService } from './rxnorm.service';
import { FdaService } from './fda.service';
import { ExternalController } from './external.controller';
import { DrugSyncService } from './drug-sync.service';
import { OcrService } from './ocr.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [RxNormService, FdaService, DrugSyncService, OcrService],
  controllers: [ExternalController],
  exports: [RxNormService, FdaService, DrugSyncService, OcrService],
})
export class ExternalModule {}