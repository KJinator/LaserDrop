// Adopted from https://www.scaler.com/topics/c/implementation-of-queue-using-linked-list/

#include <stdio.h> 
#include <stdlib.h>
#include "queue.h"

queue_t queue_new () {
    queue_t new = calloc(1, sizeof(struct queue));
    return new;
}

void enqueue(queue_t queue, size_t value) {
    struct node * ptr;
    ptr = (struct node * ) malloc(sizeof(struct node));
    ptr->data = value;
    ptr->next = NULL;
    if ((queue->front == NULL) && (queue->rear == NULL)) {
        queue->front = queue->rear = ptr;
    } else {
        queue->rear->next = ptr;
        queue->rear = ptr;
    }
    // printf("Node is Inserted\n\n");
}

// Dequeue() operation on a queue
size_t dequeue(queue_t queue) {
    struct node * temp = queue->front;
    size_t temp_data = queue->front->data;
    queue->front = queue->front->next;
    if (queue->front == NULL) queue->rear = NULL;
    free(temp);
    return temp_data;
}

size_t peek (queue_t queue) {
    return queue->front->data;
}

bool queue_empty (queue_t queue) {
    return queue->front == NULL && queue->rear == NULL;
}

void queue_free (queue_t queue) {
    while (!queue_empty(queue)) {
        dequeue(queue);
    }
    free(queue);
}