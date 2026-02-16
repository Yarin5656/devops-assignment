locals {
  bucket_name = "task2-ingest"
  queue_name  = "task2-ingest-queue"
}

resource "aws_s3_bucket" "ingest" {
  bucket = local.bucket_name
}

resource "aws_sqs_queue" "ingest_queue" {
  name = local.queue_name
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.ingest_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.ingest_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.ingest.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "ingest_to_sqs" {
  bucket = aws_s3_bucket.ingest.id

  queue {
    queue_arn = aws_sqs_queue.ingest_queue.arn
    events    = ["s3:ObjectCreated:*"]

    filter_suffix = ".geojson"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

resource "aws_iam_role" "worker_role" {
  name = "task2-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "worker_access" {
  name = "task2-worker-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.ingest.arn, "${aws_s3_bucket.ingest.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [aws_sqs_queue.ingest_queue.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.worker_access.arn
}

output "bucket_name" {
  value = aws_s3_bucket.ingest.bucket
}

output "queue_url" {
  value = aws_sqs_queue.ingest_queue.id
}

output "queue_arn" {
  value = aws_sqs_queue.ingest_queue.arn
}