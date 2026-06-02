import { Module } from '@nestjs/common';
import { DrugsService } from './drugs.service';
import { DrugsController } from './drugs.controller';

@Module({
  providers: [DrugsService],
  controllers: [DrugsController],
  exports: [DrugsService],
})
export class DrugsModule {}