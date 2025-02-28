"""
Python job scheduling for humans.

github.com/ibrb/python-aioschedule

Forked from github.com/dbader/schedule.

An in-process scheduler for periodic jobs that uses the builder pattern
for configuration. Schedule lets you run Python functions (or any other
callable) periodically at pre-determined intervals using a simple,
human-friendly syntax.

Inspired by Addam Wiggins' article "Rethinking Cron" [1] and the
"clockwork" Ruby module [2][3].

Features:
    - A simple to use API for scheduling jobs.
    - Very lightweight and no external dependencies.
    - Excellent test coverage.
    - Works with Python 3.5+

Usage:
    >>> import asyncio
    >>> import aioschedule as schedule
    >>> import time

    >>> async def job(message='stuff', n=1):
    >>>     print("Asynchronous invocation (%s) of I'm working on:" % n, message)
    >>>     asyncio.sleep(1)

    >>> for i in range(1,3):
    >>>     schedule.every(1).seconds.do(job, n=i)
    >>> schedule.every(5).to(10).days.do(job)
    >>> schedule.every().hour.do(job, message='things')
    >>> schedule.every().day.at("10:30").do(job)

    >>> loop = asyncio.get_event_loop()
    >>> while True:
    >>>     loop.run_until_complete(schedule.run_pending())
    >>>     time.sleep(0.1)

[1] https://adam.herokuapp.com/past/2010/4/13/rethinking_cron/
[2] https://github.com/Rykian/clockwork
[3] https://adam.herokuapp.com/past/2010/6/30/replace_cron_with_clockwork/
"""
import asyncio
import datetime
import functools
import logging
import random
import warnings

from typing import cast
from typing import Any
from typing import Awaitable
from typing import Callable


logger = logging.getLogger('schedule')


class CancelJob(object):
    """
    Can be returned from a job to unschedule itself.
    """
    pass


class Scheduler(object):
    """
    Objects instantiated by the :class:`Scheduler <Scheduler>` are
    factories to create jobs, keep record of scheduled jobs and
    handle their execution.
    """
    jobs: list['Job']

    def __init__(self):
        self.jobs = []

    async def run_pending(
        self,
        *args: Any,
        **kwargs: Any
    ) -> tuple[list[asyncio.Future[Any]], list[asyncio.Future[Any]]]:
        """Run all jobs that are scheduled to run.

        Please note that it is *intended behavior that run_pending()
        does not run missed jobs*. For example, if you've registered a job
        that should run every minute and you only call run_pending()
        in one hour increments then your job won't be run 60 times in
        between but only once.

        *timeout* can be used to control the maximum number of seconds to wait before
        returning.  *timeout* can be an int or float.  If *timeout* is not specified
        or ``None``, there is no limit to the wait time.

        *return_when* indicates when this function should return.  It must be one of
        the following constants:

        .. tabularcolumns:: |l|L|

        +-----------------------------+----------------------------------------+
        | Constant                    | Description                            |
        +=============================+========================================+
        | :const:`FIRST_COMPLETED`    | The function will return when any      |
        |                             | future finishes or is cancelled.       |
        +-----------------------------+----------------------------------------+
        | :const:`FIRST_EXCEPTION`    | The function will return when any      |
        |                             | future finishes by raising an          |
        |                             | exception.  If no future raises an     |
        |                             | exception then it is equivalent to     |
        |                             | :const:`ALL_COMPLETED`.                |
        +-----------------------------+----------------------------------------+
        | :const:`ALL_COMPLETED`      | The function will return when all      |
        |                             | futures finish or are cancelled.       |
        +-----------------------------+----------------------------------------+
        """
        jobs: list[asyncio.Task[Any]] = [
            asyncio.create_task(job.run())
            for job in self.jobs if job.should_run
        ]
        if not jobs:
            return [], []

        return await asyncio.wait(jobs, *args, **kwargs)

    async def run_all(
        self,
        delay_seconds: int = 0,
        *args: Any,
        **kwargs: Any
    ):
        """Run all jobs regardless if they are scheduled to run or not.

        *timeout* can be used to control the maximum number of seconds to wait before
        returning.  *timeout* can be an int or float.  If *timeout* is not specified
        or ``None``, there is no limit to the wait time.

        *return_when* indicates when this function should return.  It must be one of
        the following constants:

        .. tabularcolumns:: |l|L|

        +-----------------------------+----------------------------------------+
        | Constant                    | Description                            |
        +=============================+========================================+
        | :const:`FIRST_COMPLETED`    | The function will return when any      |
        |                             | future finishes or is cancelled.       |
        +-----------------------------+----------------------------------------+
        | :const:`FIRST_EXCEPTION`    | The function will return when any      |
        |                             | future finishes by raising an          |
        |                             | exception.  If no future raises an     |
        |                             | exception then it is equivalent to     |
        |                             | :const:`ALL_COMPLETED`.                |
        +-----------------------------+----------------------------------------+
        | :const:`ALL_COMPLETED`      | The function will return when all      |
        |                             | futures finish or are cancelled.       |
        +-----------------------------+----------------------------------------+
        """
        if delay_seconds:
            warnings.warn("The `delay_seconds` parameter is deprecated.",
                DeprecationWarning)
        jobs = [self._run_job(job) for job in self.jobs[:]]
        if not jobs:
            return cast(Any, []), cast(Any, [])

        return await asyncio.wait(map(asyncio.create_task, jobs), *args, **kwargs)

    def clear(self, tag: str | None = None):
        """
        Deletes scheduled jobs marked with the given tag, or all jobs
        if tag is omitted.

        :param tag: An identifier used to identify a subset of
                    jobs to delete
        """
        if tag is None:
            del self.jobs[:]
        else:
            self.jobs[:] = (job for job in self.jobs if tag not in job.tags)

    def cancel_job(self, job: 'Job'):
        """
        Delete a scheduled job.

        :param job: The job to be unscheduled
        """
        try:
            self.jobs.remove(job)
        except ValueError:
            pass

    def every(self, interval: int = 1):
        """
        Schedule a new periodic job.

        :param interval: A quantity of a certain time unit
        :return: An unconfigured :class:`Job <Job>`
        """
        job = Job(interval, self)
        return job

    async def _run_job(self, job: 'Job'):
        ret = await job.run()
        if isinstance(ret, CancelJob) or ret is CancelJob:
            self.cancel_job(job)

    @property
    def next_run(self):
        """
        Datetime when the next job should run.

        :return: A :class:`~datetime.datetime` object
        """
        return min(self.jobs).next_run

    @property
    def idle_seconds(self):
        """
        :return: Number of seconds until
                 :meth:`next_run <Scheduler.next_run>`.
        """
        return (self.next_run - datetime.datetime.now()).total_seconds()


class Job(object):
    """
    A periodic job as used by :class:`Scheduler`.

    :param interval: A quantity of a certain time unit
    :param scheduler: The :class:`Scheduler <Scheduler>` instance that
                      this job will register itself with once it has
                      been fully configured in :meth:`Job.do()`.

    Every job runs at a given fixed time interval that is defined by:

    * a :meth:`time unit <Job.second>`
    * a quantity of `time units` defined by `interval`

    A job is usually created and returned by :meth:`Scheduler.every`
    method, which also defines its `interval`.
    """
    job_func: Callable[..., Awaitable[Any]]
    tags: set[str]

    def __init__(self, interval: int, scheduler: Scheduler | None = None):
        n = datetime.datetime.now()
        self.interval = interval  # pause interval * unit between runs
        self.latest = None  # upper limit to the interval
        self.unit = None  # time units, e.g. 'minutes', 'hours', ...
        self.at_time = None  # optional time at which this job runs
        self.last_run = n  # datetime of the last run
        self.next_run = n  # datetime of the next run
        self.period = None  # timedelta between runs, only valid for
        self.start_day = None  # Specific day of the week to start on
        self.tags = set()  # unique set of tags for the job
        self.scheduler = scheduler  # scheduler to register with

    def __lt__(self, other: 'Job'):
        """
        PeriodicJobs are sortable based on the scheduled time they
        run next.
        """
        assert self.next_run is not None
        assert other.next_run is not None
        return self.next_run < other.next_run

    def __repr__(self):

        def format_time(t: datetime.datetime):
            return t.strftime('%Y-%m-%d %H:%M:%S') if t else '[never]'

        timestats = '(last run: %s, next run: %s)' % (
                    format_time(self.last_run), format_time(self.next_run))

        if hasattr(self.job_func, '__name__'):
            job_func_name = self.job_func.__name__
        else:
            job_func_name = repr(self.job_func)
        args = [repr(x) for x in self.job_func.args]
        kwargs = ['%s=%s' % (k, repr(v))
                  for k, v in self.job_func.keywords.items()]
        call_repr = job_func_name + '(' + ', '.join(args + kwargs) + ')'

        if self.at_time is not None:
            return 'Every %s %s at %s do %s %s' % (
                   self.interval,
                   self.unit[:-1] if self.interval == 1 else self.unit,
                   self.at_time, call_repr, timestats)
        else:
            fmt = (
                'Every %(interval)s ' +
                ('to %(latest)s ' if self.latest is not None else '') +
                '%(unit)s do %(call_repr)s %(timestats)s'
            )

            return fmt % dict(
                interval=self.interval,
                latest=self.latest,
                unit=(self.unit[:-1] if self.interval == 1 else self.unit),
                call_repr=call_repr,
                timestats=timestats
            )

    @property
    def second(self):
        assert self.interval == 1, 'Use seconds instead of second'
        return self.seconds

    @property
    def seconds(self):
        self.unit = 'seconds'
        return self

    @property
    def minute(self):
        assert self.interval == 1, 'Use minutes instead of minute'
        return self.minutes

    @property
    def minutes(self):
        self.unit = 'minutes'
        return self

    @property
    def hour(self):
        assert self.interval == 1, 'Use hours instead of hour'
        return self.hours

    @property
    def hours(self):
        self.unit = 'hours'
        return self

    @property
    def day(self):
        assert self.interval == 1, 'Use days instead of day'
        return self.days

    @property
    def days(self):
        self.unit = 'days'
        return self

    @property
    def week(self):
        assert self.interval == 1, 'Use weeks instead of week'
        return self.weeks

    @property
    def weeks(self):
        self.unit = 'weeks'
        return self

    @property
    def monday(self):
        assert self.interval == 1, 'Use mondays instead of monday'
        self.start_day = 'monday'
        return self.weeks

    @property
    def tuesday(self):
        assert self.interval == 1, 'Use tuesdays instead of tuesday'
        self.start_day = 'tuesday'
        return self.weeks

    @property
    def wednesday(self):
        assert self.interval == 1, 'Use wedesdays instead of wednesday'
        self.start_day = 'wednesday'
        return self.weeks

    @property
    def thursday(self):
        assert self.interval == 1, 'Use thursday instead of thursday'
        self.start_day = 'thursday'
        return self.weeks

    @property
    def friday(self):
        assert self.interval == 1, 'Use fridays instead of friday'
        self.start_day = 'friday'
        return self.weeks

    @property
    def saturday(self):
        assert self.interval == 1, 'Use saturdays instead of saturday'
        self.start_day = 'saturday'
        return self.weeks

    @property
    def sunday(self):
        assert self.interval == 1, 'Use sundays instead of sunday'
        self.start_day = 'sunday'
        return self.weeks

    def tag(self, *tags: set[str]):
        """
        Tags the job with one or more unique indentifiers.

        Tags must be hashable. Duplicate tags are discarded.

        :param tags: A unique list of ``Hashable`` tags.
        :return: The invoked job instance
        """
        self.tags.update(*tags)
        return self

    def at(self, time_str: str):
        """
        Schedule the job every day at a specific time.

        Calling this is only valid for jobs scheduled to run
        every N day(s).

        :param time_str: A string in `XX:YY` format.
        :return: The invoked job instance
        """
        assert self.unit in ('days', 'hours') or self.start_day
        hour, minute = time_str.split(':')
        minute = int(minute)
        if self.unit == 'days' or self.start_day:
            hour = int(hour)
            assert 0 <= hour <= 23
        elif self.unit == 'hours':
            hour = 0
        assert 0 <= minute <= 59
        self.at_time = datetime.time(int(hour), int(minute))
        return self

    def to(self, latest: int):
        """
        Schedule the job to run at an irregular (randomized) interval.

        The job's interval will randomly vary from the value given
        to  `every` to `latest`. The range defined is inclusive on
        both ends. For example, `every(A).to(B).seconds` executes
        the job function every N seconds such that A <= N <= B.

        :param latest: Maximum interval between randomized job runs
        :return: The invoked job instance
        """
        self.latest = latest
        return self

    def do(self, job_func: Callable[..., Awaitable[Any]], *args: Any, **kwargs: Any):
        """
        Specifies the job_func that should be called every time the
        job runs.

        Any additional arguments are passed on to job_func when
        the job runs.

        :param job_func: The function to be scheduled
        :return: The invoked job instance
        """
        assert self.scheduler is not None
        self.job_func = functools.partial(job_func, *args, **kwargs)
        try:
            functools.update_wrapper(self.job_func, job_func)
        except AttributeError:
            # job_funcs already wrapped by functools.partial won't have
            # __name__, __module__ or __doc__ and the update_wrapper()
            # call will fail.
            pass
        self._schedule_next_run()
        self.scheduler.jobs.append(self)
        return self

    @property
    def should_run(self) -> bool:
        """
        :return: ``True`` if the job should be run now.
        """
        if self.next_run is None:
            return True
        return datetime.datetime.now() >= self.next_run

    async def run(self):
        """
        Run the job and immediately reschedule it.

        :return: The return value returned by the `job_func`
        """
        logger.info('Running job %s', self)
        ret = await self.job_func()
        self.last_run = datetime.datetime.now()
        self._schedule_next_run()
        return ret

    def _schedule_next_run(self):
        """
        Compute the instant when this job should run next.
        """
        assert self.unit in ('seconds', 'minutes', 'hours', 'days', 'weeks')

        if self.latest is not None:
            assert self.latest >= self.interval
            interval = random.randint(self.interval, self.latest)
        else:
            interval = self.interval

        self.period = datetime.timedelta(**{self.unit: interval})
        self.next_run = datetime.datetime.now() + self.period
        if self.start_day is not None:
            assert self.unit == 'weeks'
            weekdays = (
                'monday',
                'tuesday',
                'wednesday',
                'thursday',
                'friday',
                'saturday',
                'sunday'
            )
            assert self.start_day in weekdays
            weekday = weekdays.index(self.start_day)
            days_ahead = weekday - self.next_run.weekday()
            if days_ahead <= 0:  # Target day already happened this week
                days_ahead += 7
            self.next_run += datetime.timedelta(days_ahead) - self.period
        if self.at_time is not None:
            assert self.unit in ('days', 'hours') or self.start_day is not None
            kwargs: dict[str, int] = {
                'minute': self.at_time.minute,
                'second': self.at_time.second,
                'microsecond': 0
            }
            if self.unit == 'days' or self.start_day is not None:
                kwargs['hour'] = self.at_time.hour
            self.next_run = self.next_run.replace(tzinfo=None, **kwargs)
            # If we are running for the first time, make sure we run
            # at the specified time *today* (or *this hour*) as well
            if not self.last_run:
                now = datetime.datetime.now()
                if (self.unit == 'days' and self.at_time > now.time() and
                        self.interval == 1):
                    self.next_run = self.next_run - datetime.timedelta(days=1)
                elif self.unit == 'hours' and self.at_time.minute > now.minute:
                    self.next_run = self.next_run - datetime.timedelta(hours=1)
        if self.start_day is not None and self.at_time is not None:
            # Let's see if we will still make that time we specified today
            if (self.next_run - datetime.datetime.now()).days >= 7:
                self.next_run -= self.period


# The following methods are shortcuts for not having to
# create a Scheduler instance:

#: Default :class:`Scheduler <Scheduler>` object
default_scheduler = Scheduler()

#: Default :class:`Jobs <Job>` list
jobs = default_scheduler.jobs  # todo: should this be a copy, e.g. jobs()?


def every(interval: int = 1):
    """Calls :meth:`every <Scheduler.every>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    return default_scheduler.every(interval)


async def run_pending():
    """Calls :meth:`run_pending <Scheduler.run_pending>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    await default_scheduler.run_pending()


async def run_all(delay_seconds: int = 0):
    """Calls :meth:`run_all <Scheduler.run_all>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    await default_scheduler.run_all(delay_seconds=delay_seconds)


def clear(tag: str | None = None):
    """Calls :meth:`clear <Scheduler.clear>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    default_scheduler.clear(tag)


def cancel_job(job: Job):
    """Calls :meth:`cancel_job <Scheduler.cancel_job>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    default_scheduler.cancel_job(job)


def next_run():
    """Calls :meth:`next_run <Scheduler.next_run>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    return default_scheduler.next_run


def idle_seconds():
    """Calls :meth:`idle_seconds <Scheduler.idle_seconds>` on the
    :data:`default scheduler instance <default_scheduler>`.
    """
    return default_scheduler.idle_seconds
