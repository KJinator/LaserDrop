#ifndef QUEUE_H
#define QUEUE_H
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>

// Structure to create a node with data and the next pointer
struct node {
    size_t data;
    struct node *next;
};

struct queue {
    struct node *front;
    struct node *rear;
};

typedef struct queue *queue_t;

queue_t queue_new ();

void enqueue (queue_t queue, size_t value);

size_t dequeue (queue_t queue);

size_t peek (queue_t queue);

bool queue_empty (queue_t queue);

void queue_free (queue_t queue);

#endif