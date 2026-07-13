import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ActivityLogsService {
  constructor(private prisma: PrismaService) {}

  async logActivity(
    userId: string,
    action: string,
    details?: string,
    ipAddress?: string,
  ) {
    try {
      return await this.prisma.activityLog.create({
        data: {
          userId,
          action,
          details,
          ipAddress,
        },
      });
    } catch (error) {
      // Prevent activity log failures from crashing the main request flow
      console.error('Failed to write activity log:', error);
    }
  }

  async getActivityLogs(limit = 100, page = 1) {
    const skip = (page - 1) * limit;
    const [logs, total] = await Promise.all([
      this.prisma.activityLog.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: {
            select: {
              name: true,
              email: true,
              role: true,
            },
          },
        },
        take: limit,
        skip,
      }),
      this.prisma.activityLog.count(),
    ]);

    return {
      logs,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
