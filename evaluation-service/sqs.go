package main

import (
	"context"
	"encoding/json"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/sqs"
)

type EvaluationEvent struct {
	UserID    string    `json:"user_id"`
	FlagName  string    `json:"flag_name"`
	Result    bool      `json:"result"`
	Timestamp time.Time `json:"timestamp"`
}

func (a *App) sendEvaluationEvent(ctx context.Context, userID, flagName string, result bool) {
	if a.SqsSvc == nil || a.SqsQueueURL == "" {
		logCtx(ctx, "[SQS_DISABLED] Evento: User '%s', Flag '%s', Result '%t'", sanitize(userID), sanitize(flagName), result)
		return
	}

	event := EvaluationEvent{
		UserID:    userID,
		FlagName:  flagName,
		Result:    result,
		Timestamp: time.Now().UTC(),
	}

	body, err := json.Marshal(event)
	if err != nil {
		logCtx(ctx, "Erro ao serializar evento SQS: %v", err)
		return
	}

	_, err = a.SqsSvc.SendMessageWithContext(ctx, &sqs.SendMessageInput{
		MessageBody: aws.String(string(body)),
		QueueUrl:    aws.String(a.SqsQueueURL),
	})

	if err != nil {
		logCtx(ctx, "Erro ao enviar mensagem para SQS: %v", err)
	} else {
		logCtx(ctx, "Evento de avaliacao enviado para SQS (Flag: %s)", sanitize(flagName))
	}
}
