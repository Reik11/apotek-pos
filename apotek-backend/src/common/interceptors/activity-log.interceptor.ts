import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { ActivityLogsService } from '../../modules/activity-logs/activity-logs.service';

@Injectable()
export class ActivityLogInterceptor implements NestInterceptor {
  constructor(private readonly activityLogsService: ActivityLogsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const httpContext = context.switchToHttp();
    const request = httpContext.getRequest();
    const { method, url, ip } = request;

    // We only log modifying actions or authentication actions
    const isWrite = ['POST', 'PUT', 'DELETE', 'PATCH'].includes(method);
    if (!isWrite) {
      return next.handle();
    }

    return next.handle().pipe(
      tap((responseBody) => {
        let userId: string | null = null;
        let action = `${method} ${url}`;

        // 1. Identify User
        if (request.user && request.user.id) {
          userId = request.user.id;
        } else if (responseBody && responseBody.user && responseBody.user.id) {
          // Captures userId from login/register responses where JWT isn't verified yet
          userId = responseBody.user.id;
        }

        if (!userId) {
          return; // Can't associate log with a user
        }

        // 2. Format Action Name
        const path = url.split('?')[0]; // strip query params
        if (path.endsWith('/auth/login')) {
          action = 'LOGIN';
        } else if (path.endsWith('/auth/google')) {
          action = 'LOGIN_GOOGLE';
        } else if (path.endsWith('/auth/register')) {
          action = 'REGISTER';
        } else if (path.includes('/transactions')) {
          action = `${method}_TRANSACTION`;
        } else if (path.includes('/orders')) {
          action = `${method}_ORDER`;
        } else if (path.includes('/drugs')) {
          action = `${method}_DRUG`;
        } else if (path.includes('/users')) {
          action = `${method}_USER`;
        } else if (path.includes('/outlets')) {
          action = `${method}_OUTLET`;
        } else if (path.includes('/suppliers')) {
          action = `${method}_SUPPLIER`;
        } else if (path.includes('/purchase-orders')) {
          action = `${method}_PURCHASE_ORDER`;
        } else if (path.includes('/shifts')) {
          action = `${method}_SHIFT`;
        } else if (path.includes('/reports')) {
          action = `${method}_REPORT`;
        }

        // 3. Format Details (scrubbing sensitive keys)
        let details = '';
        if (request.body) {
          const bodyCopy = { ...request.body };
          const sensitiveKeys = [
            'password',
            'currentPassword',
            'newPassword',
            'otp',
            'token',
            'idToken',
          ];
          sensitiveKeys.forEach((key) => {
            if (key in bodyCopy) {
              bodyCopy[key] = '[HIDDEN]';
            }
          });
          details = JSON.stringify(bodyCopy);
        }

        // 4. Log to Database
        this.activityLogsService.logActivity(userId, action, details, ip);
      }),
    );
  }
}
