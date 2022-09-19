# ref: https://github.com/twitterdev/Twitter-API-v2-sample-code/blob/aa131cfa3ee2d440db22fb9f1753374b26b7125b/Filtered-Stream/filtered_stream.py#L10

import requests
import os
import json
import io
import time
from datetime import datetime

from google.cloud import pubsub_v1
from google.cloud import storage


def get_checkpoint(storage_client, bucket_name="tweeter-function", checkpoint_file="tweet_id_checkpoint"):
    """
        Gets the checkpoint file stored in GCS
    """
    bucket = storage_client.get_bucket(bucket_name)
    checkpoint = bucket.get_blob(checkpoint_file)

    return checkpoint.download_as_string().decode("utf-8")

    
# TODO: duplicated variable definitions
def set_checkpoint(storage_client, new_checkpoint, bucket_name="tweeter-function", checkpoint_file="tweet_id_checkpoint"):
    """
        Sets the checkpoint file stored in GCS 
    """
    bucket = storage_client.get_bucket(bucket_name)
    checkpoint = bucket.get_blob(checkpoint_file)
    with checkpoint.open('w') as bfile:
        bfile.write(new_checkpoint)


def get_auth_headercreds():
    """
        returns Twitter API Token from an environment variable
    """
    return os.environ.get('TWEET_TOKEN')


def convert_timestamp(created_at):
    """
        Returns an epoch version of a human readable time string.
    """
    strp_format = '%Y-%m-%dT%H:%M:%S.000Z'

    try:
        epoch = int(datetime.strptime(created_at, '%Y-%m-%dT%H:%M:%S.000Z').timestamp())
        return epoch
    except Exception as e:
        return None


def get_tweets(publisher_client, topic_path, since_id,keyword, depth=0, next_token=None):
    """
        Gets all the tweets after a given 'since_id' value. That is, the latest tweet we've retrieved. 
    """

    token = get_auth_headercreds()
    auth_header = {'Authorization' : 'Bearer %s' % token }
    base_url = 'https://api.twitter.com/2/tweets/search/recent?max_results=100&expansions=author_id&tweet.fields=created_at'
    base_url = '%s&query=%s -is:retweet&since_id=%s' % (base_url, keyword,since_id)
    
    # Next token will be passed in during pagination if need
    if next_token != None:
        base_url = '%s&next_token=%s' % (base_url, next_token)

    resp = requests.get(base_url, headers=auth_header).json()
    print(resp)

    if 'data' in resp:

        for tweet in resp['data']:
            tweet['created_at_epoch'] = convert_timestamp(tweet['created_at'])
            # Arrange tweet in Avro Schema order for topic
            formatted_tweet = {}
            formatted_tweet['id'] = tweet.get('id')
            formatted_tweet['created_at'] = tweet.get('created_at')
            formatted_tweet['created_at_epoch'] = tweet.get('created_at_epoch')
            formatted_tweet['text'] = tweet.get('text')
            formatted_tweet['author_id'] = tweet.get('author_id')
            print(json.dumps(formatted_tweet))

            # TODO: Add callback/await functionality, simple test for now 
            publish_future = publisher_client.publish(topic_path, json.dumps(formatted_tweet).encode("utf-8"))
        

        # .get() will return None if next_token doesn't exist. 
        next_token = resp.get('meta').get('next_token')

        # don't go over 10 iterations OR if Twitter doesn't provide next_token and quite paginating
        if depth > 10 or next_token == None:
            storage_client = storage.Client(os.environ['GOOGLE_PROJECT_ID'])
            # let's end and update the checkpoint value
            set_checkpoint(storage_client, tweet.get('id'))
        else:
            get_tweets(publisher_client, topic_path, since_id, keyword=keyword, depth = depth + 1, next_token=next_token)
        
    else:
        print('Unable to query the twitter API')

def main(event_data, context):

    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(os.environ['GOOGLE_PROJECT_ID'], os.environ['GOOGLE_PUBSUB_TOPIC'])
    topic = publisher.get_topic(request={"topic": topic_path})
    encoding = topic.schema_settings.encoding

    storage_client = storage.Client(os.environ['GOOGLE_PROJECT_ID'])
    last_ingested_tweet = get_checkpoint(storage_client)

    tweets = get_tweets(publisher, topic_path, last_ingested_tweet, 'cobaltstrike')

    print(tweets)
