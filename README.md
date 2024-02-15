# Useless DB
[![Pub Package](https://img.shields.io/pub/v/useless_db.svg)](https://pub.dev/packages/useless_db)
[![GitHub Issues](https://img.shields.io/github/issues/TheTosters/useless_db.svg)](https://github.com/TheTosters/useless_db/issues)
[![GitHub Forks](https://img.shields.io/github/forks/TheTosters/useless_db.svg)](https://github.com/TheTosters/useless_db/network)
[![GitHub Stars](https://img.shields.io/github/stars/TheTosters/useless_db.svg)](https://github.com/TheTosters/useless_db/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/TheTosters/useless_db/blob/master/LICENSE)

## What is it?

This is my approach to create simple DB for small / medium amount of data. I've no experience in
such kind of software and not aiming to create database for production purposes. As name states it
almost certainly will be useless for you, however I've plans to replace mongoDB which I currently use
in one of my project with this abomination and see how it goes.

## Simplicity

There is no fancy stuff and probably never will be, I'm aiming to have something which works
similar to DB. There is no concern about efficiency nor other top priorities for DB systems.

## No Web & mobile support

It was never in scope of this project to run on mobile devices nor web. It is designed and targeted
only for linux platform, don't know if it run on any other platform and other platforms are not
in my area of interest. 

## Standalone

It's possible to embed this into your application directly (similar you do with sqlite3). But I'm not
convinced that this is the best solution. At moment this doc is being written my plan is to use this
DB as a server-client. An yes other project which introduce server and client layer will be deployed. 

## Server - client

When I prepare and deploy separate packages for this purpose this section will be updated.

## Integration

There is plan to integrate this with [Entity Serializer](https://pub.dev/packages/entity_serializer)
which will be probably useless for you as well :D

## Examples

I suggest refer to tests more then example. At least at this moment, we will see how this project
will grow.

## Collaboration

If you reached this point I must admire you are tough. I'm open for discussion / suggestions, if
you feel that your PR is great and want to be part of this project feel free to catch me on github :)