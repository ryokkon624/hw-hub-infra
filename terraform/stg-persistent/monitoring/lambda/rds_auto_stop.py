import boto3
import json
import os
from datetime import datetime, timezone, timedelta


def lambda_handler(event, context):
    rds_id = os.environ["RDS_INSTANCE_IDENTIFIER"]
    delay_minutes = int(os.environ.get("AUTO_STOP_DELAY_MINUTES", "30"))
    scheduler_role_arn = os.environ["SCHEDULER_ROLE_ARN"]

    # RDS-EVENT-0088 via EventBridge Rule → schedule a delayed stop
    if event.get("source") == "aws.rds":
        _schedule_delayed_stop(
            lambda_arn=context.invoked_function_arn,
            scheduler_role_arn=scheduler_role_arn,
            delay_minutes=delay_minutes,
        )
    else:
        # Direct invocation from daily scheduler or one-time delayed scheduler
        _stop_rds(rds_id)


def _stop_rds(rds_id: str) -> None:
    rds = boto3.client("rds")
    try:
        rds.stop_db_instance(DBInstanceIdentifier=rds_id)
        print(f"Stopped RDS instance: {rds_id}")
    except rds.exceptions.InvalidDBInstanceStateFault:
        # Already stopped / stopping — not an error for forced-stop use case
        print(f"RDS instance {rds_id} is already stopped or in a non-stoppable state")
    except Exception as e:
        print(f"Failed to stop RDS instance {rds_id}: {e}")
        raise


def _schedule_delayed_stop(
    lambda_arn: str, scheduler_role_arn: str, delay_minutes: int
) -> None:
    scheduler = boto3.client("scheduler")
    stop_at = datetime.now(timezone.utc) + timedelta(minutes=delay_minutes)
    schedule_name = (
        f"stg-persistent-rds-delayed-stop-{stop_at.strftime('%Y%m%d%H%M%S')}"
    )

    scheduler.create_schedule(
        Name=schedule_name,
        GroupName="default",
        ScheduleExpression=f"at({stop_at.strftime('%Y-%m-%dT%H:%M:%S')})",
        ScheduleExpressionTimezone="UTC",
        State="ENABLED",
        ActionAfterCompletion="DELETE",
        FlexibleTimeWindow={"Mode": "OFF"},
        Target={
            "Arn": lambda_arn,
            "RoleArn": scheduler_role_arn,
            "Input": json.dumps({"action": "stop"}),
            "RetryPolicy": {
                "MaximumEventAgeInSeconds": 3600,
                "MaximumRetryAttempts": 0,
            },
        },
    )
    print(
        f"Scheduled RDS stop at {stop_at.isoformat()} "
        f"(delay: {delay_minutes}min, schedule: {schedule_name})"
    )
