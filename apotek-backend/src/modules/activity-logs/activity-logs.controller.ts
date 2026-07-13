import {
  Controller,
  Get,
  Query,
  UseGuards,
  Request,
  ForbiddenException,
  ParseIntPipe,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ActivityLogsService } from './activity-logs.service';

@Controller('activity-logs')
@UseGuards(AuthGuard('jwt'))
export class ActivityLogsController {
  constructor(private readonly activityLogsService: ActivityLogsService) {}

  @Get()
  async getLogs(
    @Request() req: any,
    @Query('limit') limit?: string,
    @Query('page') page?: string,
  ) {
    // Only SUPER_ADMIN and ADMIN are allowed to view audit logs
    if (req.user.role !== 'SUPER_ADMIN' && req.user.role !== 'ADMIN') {
      throw new ForbiddenException(
        'Hanya Admin atau Super Admin yang dapat mengakses log aktivitas.',
      );
    }

    const limitVal = limit ? parseInt(limit, 10) : 50;
    const pageVal = page ? parseInt(page, 10) : 1;

    return this.activityLogsService.getActivityLogs(limitVal, pageVal);
  }
}
