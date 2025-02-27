aioschedule
===========


.. image:: https://api.travis-ci.org/ibrb/python-aioschedule.svg?branch=master
        :target: https://travis-ci.org/ibrb/python-aioschedule

.. image:: https://coveralls.io/repos/ibrb/python-aioschedule/badge.svg?branch=master
        :target: https://coveralls.io/r/ibrb/python-aioschedule

.. image:: https://img.shields.io/pypi/v/aioschedule.svg
        :target: https://pypi.python.org/pypi/aioschedule

.. image:: https://media.ibrb.org/ibr/images/logos/landscape1200.png
        :target: https://media.ibrb.org/ibr/images/logos/landscape1200.png


Python job scheduling for humans. Forked and modified from github.com/dbader/schedule.

An in-process scheduler for periodic jobs that uses the builder pattern
for configuration. Schedule lets you run Python functions (or any other
callable) periodically at pre-determined intervals using a simple,
human-friendly syntax.

Inspired by `Adam Wiggins' <https://github.com/adamwiggins>`_ article `"Rethinking Cron" <https://adam.herokuapp.com/past/2010/4/13/rethinking_cron/>`_ and the `clockwork <https://github.com/Rykian/clockwork>`_ Ruby module.

Features
--------
- A simple to use API for scheduling jobs.
- Very lightweight and no external dependencies.
- Excellent test coverage.
- Tested on Python 3.5, and 3.6

Usage
-----

.. code-block:: bash

    $ pip install aioschedule

.. code-block:: python

    import asyncio
    import aioschedule as schedule
    import time

    async def job(message: str = 'stuff', n: int = 1):
        print("Asynchronous invocation (%s) of I'm working on:" % n, message)
        await asyncio.sleep(1)

    for i in range(1,3):
        schedule.every(1).seconds.do(job, n=i)
    schedule.every(5).to(10).days.do(job)
    schedule.every().hour.do(job, message='things')
    schedule.every().day.at("10:30").do(job)

    loop = asyncio.get_event_loop()
    while True:
        loop.run_until_complete(schedule.run_pending())
        time.sleep(0.1)

Documentation
-------------

Schedule's documentation lives at `schedule.readthedocs.io <https://schedule.readthedocs.io/>`_.

Please also check the FAQ there with common questions.


Development
-----------
Run `vagrant up` to spawn a virtual machine containing the development
environment. Make sure to set the `IBR_GIT_COMMITTER_NAME` and
`IBR_GIT_COMMITTER_EMAIL` environment variables.


Meta
----

- Daniel Bader - `@dbader_org <https://twitter.com/dbader_org>`_ - mail@dbader.org
- Cochise Ruhulessin - `@magicalcochise <https://twitter.com/magicalcochise>`_ - c.ruhulessin@ibrb.org

Distributed under the MIT license. See ``LICENSE.txt`` for more information.

https://github.com/ibrb/python-aioschedule
