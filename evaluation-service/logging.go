package main

import (
	"context"
	"log"

	"go.opentelemetry.io/otel/trace"
)

func logCtx(ctx context.Context, format string, args ...any) {
	sc := trace.SpanContextFromContext(ctx)
	if sc.IsValid() {
		prefixed := append([]any{sc.TraceID().String(), sc.SpanID().String()}, args...)
		log.Printf("[trace_id=%s span_id=%s] "+format, prefixed...)
		return
	}
	log.Printf(format, args...)
}
