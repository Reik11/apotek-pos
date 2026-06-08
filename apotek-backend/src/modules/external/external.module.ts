import { Module } from '@nestjs/common';
import { RxNormService } from './rxnorm.service';
import { FdaService } from './fda.service';
import { ExternalController } from './external.controller';

@Module({
  providers: [RxNormService, FdaService],
  controllers: [ExternalController],
  exports: [RxNormService, FdaService],
})
export class ExternalModule {}