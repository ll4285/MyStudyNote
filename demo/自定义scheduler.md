```sql
CREATE TABLE `sys_task` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `task_name` varchar(255) NOT NULL COMMENT '任务名称',
  `task_remark` varchar(255) NOT NULL COMMENT '说明',
  `job_class` varchar(255) NOT NULL COMMENT '任务类',
  `cron_expression` varchar(255) NOT NULL COMMENT '规则表达式',
  `is_enable` int(11) NOT NULL COMMENT '是否启用',
  `status` int(11) NOT NULL COMMENT '状态',
  `create_time` varchar(255) NOT NULL COMMENT '创建时间',
  `update_time` varchar(255) NOT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='系统任务调度';
```

```java

    @Autowired
    SysTaskService sysTaskService ;

public JSON test(){
        DateTimeFormatter dateFormat = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
        String datetime = dateFormat.format(LocalDateTime.now());
        SysTask sysTask = new SysTask() ;
        sysTask.setTaskName("test1");
        sysTask.setTaskRemark("测试任务");
        sysTask.setJobClass(Test1.class.getCanonicalName());
        sysTask.setCronExpression("1,2,3,5,15,44 * * * * ?");
        sysTask.setStatus(0);
        sysTask.setCreateTime(datetime);
        sysTask.setUpdateTime(datetime);
        sysTask.setIsEnable(1);
        try {
            sysTaskService.insert(sysTask) ;
        } catch (SchedulerException e) {
            e.printStackTrace();
        }


        return OperationUtil.toJSON(OperationCode.GET, null) ;
    }
```



```java
package com.porshow.schedule;

/**
 * Created by liulei on 2020-09-11.
 */

import com.porshow.model.SysTask;
import com.porshow.service.schedule.SysTaskService;
import org.quartz.*;
import org.quartz.impl.StdSchedulerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationListener;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.ContextRefreshedEvent;
import java.util.List;
/**
 * 任务初始化调度
 * */

@Configuration
public class ApplicationStartQuartzJob implements ApplicationListener<ContextRefreshedEvent> {
    @Autowired
    private SysTaskService sysTaskService;

    @Override
    public void onApplicationEvent(ContextRefreshedEvent event) {
        SysTask s = new SysTask() ;
        s.setIsEnable(1);
        List<SysTask> sysTaskList = sysTaskService.selectByColumn(s);
        Scheduler scheduler=null;
        try {
            scheduler = scheduler();
        } catch (Exception e) {
            e.printStackTrace();
        }

        if(!sysTaskList.isEmpty()){
            for (SysTask sysTask : sysTaskList) {
                Class classs=null;
                try {
                    classs = Class.forName(sysTask.getJobClass());
                } catch (ClassNotFoundException e) {
                    e.printStackTrace();
                }
                JobDetail jobDetail = JobBuilder.newJob(classs).withIdentity(sysTask.getJobClass(), Scheduler.DEFAULT_GROUP).build();
                CronScheduleBuilder cronScheduleBuilder = CronScheduleBuilder.cronSchedule(sysTask.getCronExpression());
                CronTrigger cronTrigger = TriggerBuilder.newTrigger().withIdentity(sysTask.getJobClass(), Scheduler.DEFAULT_GROUP)
                        .withSchedule(cronScheduleBuilder).build();
                try {
                    scheduler.scheduleJob(jobDetail, cronTrigger);
                } catch (SchedulerException e) {
                    e.printStackTrace();
                }
            }
        }
        try {
            scheduler.start();
        } catch (SchedulerException e) {
            e.printStackTrace();
        }
    }
    /**
     * 初始注入scheduler
     * @return
     * @throws SchedulerException
     */
    @Bean(name = "stdScheduler")
    public Scheduler scheduler() throws Exception {
        SchedulerFactory schedulerFactoryBean = new StdSchedulerFactory();
        return schedulerFactoryBean.getScheduler();
    }

}
```



```java
package com.porshow.schedule;

/**
 * Created by liulei on 2020-09-11.
 */

import com.porshow.service.schedule.SysTaskService;
import org.quartz.*;
import org.quartz.impl.StdSchedulerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.annotation.Resource;
import java.util.Date;

/**
 * 任务调度
 *
 */
@Configuration
public class QuartzScheduler {

    @Resource(name = "stdScheduler")
    private Scheduler scheduler;

    /**
     * 获取Job信息
     *
     * @param name 类名
     * @return
     * @throws SchedulerException
     */
    public String getJobInfo(String name) throws SchedulerException {
        TriggerKey triggerKey = new TriggerKey(name, Scheduler.DEFAULT_GROUP);
        CronTrigger cronTrigger = (CronTrigger) scheduler.getTrigger(triggerKey);
        return String.format("time:%s,state:%s", cronTrigger.getCronExpression(),
                scheduler.getTriggerState(triggerKey).name());
    }

    /**
     * 修改某个任务的执行时间
     *
     * @param name 类名
     * @param time 任务触发时间
     * @return
     * @throws SchedulerException
     */
    public boolean modifyJob(String name, String time) throws SchedulerException {
        Date date = null;
        TriggerKey triggerKey = new TriggerKey(name, Scheduler.DEFAULT_GROUP);
        CronTrigger cronTrigger = (CronTrigger) scheduler.getTrigger(triggerKey);
        String oldTime = cronTrigger.getCronExpression();
        if (!oldTime.equalsIgnoreCase(time)) {
            CronScheduleBuilder cronScheduleBuilder = CronScheduleBuilder.cronSchedule(time);
            CronTrigger trigger = TriggerBuilder.newTrigger().withIdentity(name, Scheduler.DEFAULT_GROUP)
                    .withSchedule(cronScheduleBuilder).build();
            date = scheduler.rescheduleJob(triggerKey, trigger);
        }
        return date != null;
    }

    /**
     * 暂停所有任务
     *
     * @throws SchedulerException
     */
    public void pauseAllJob() throws SchedulerException {
        scheduler.pauseAll();
    }

    /**
     * 暂停某个任务
     *
     * @param name 类名
     */
    public void pauseJob(String name) throws SchedulerException {
        JobKey jobKey = new JobKey(name, Scheduler.DEFAULT_GROUP);
        JobDetail jobDetail = scheduler.getJobDetail(jobKey);
        if (jobDetail == null) {
            return;
        }
        scheduler.pauseJob(jobKey);
    }

    /**
     * 恢复所有任务
     *
     * @throws SchedulerException
     */
    public void resumeAllJob() throws SchedulerException {
        scheduler.resumeAll();
    }

    /**
     * 恢复某个任务
     *
     * @param name  类名
     */
    public void resumeJob(String name) throws SchedulerException {
        JobKey jobKey = new JobKey(name, Scheduler.DEFAULT_GROUP);
        JobDetail jobDetail = scheduler.getJobDetail(jobKey);
        if (jobDetail == null) {
            return;
        }
        scheduler.resumeJob(jobKey);
    }

    /**
     * 删除某个任务
     *
     * @param name 类名
     */
    public void deleteJob(String name) throws SchedulerException {
        JobKey jobKey = new JobKey(name, Scheduler.DEFAULT_GROUP);
        JobDetail jobDetail = scheduler.getJobDetail(jobKey);
        if (jobDetail == null) {
            return;
        }
        scheduler.deleteJob(jobKey);
    }

    /**
     * 添加定时器
     *
     * @param name 类名
     * @param time 任务触发时间
     * @throws SchedulerException
     */
    public void addJob(String name,String time) throws SchedulerException {
        Class classs = null;
        try {
            classs = Class.forName(name);
        } catch (ClassNotFoundException e1) {
            e1.printStackTrace();
        }
        JobDetail jobDetail = JobBuilder.newJob(classs).withIdentity(name, Scheduler.DEFAULT_GROUP).build();
        CronScheduleBuilder cronScheduleBuilder = CronScheduleBuilder.cronSchedule(time);
        CronTrigger cronTrigger = TriggerBuilder.newTrigger().withIdentity(name, Scheduler.DEFAULT_GROUP)
                .withSchedule(cronScheduleBuilder).build();
        scheduler.scheduleJob(jobDetail, cronTrigger);
    }

}
```

```java
package com.porshow.schedule;

import lombok.extern.slf4j.Slf4j;
import org.quartz.Job;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.springframework.stereotype.Component;

/**
 * Created by liulei on 2020-09-11.
 */

@Slf4j
public class Test1 implements Job {
    @Override
    public void execute(JobExecutionContext jobExecutionContext) throws JobExecutionException {
        log.info("Test1..............");
    }
}
```

```java
package com.porshow.service.schedule;

import com.porshow.model.SysTask;
import org.quartz.SchedulerException;

import java.util.List;

public interface SysTaskService {
    int deleteByPrimaryKey(Integer id);

    int insert(SysTask record) throws SchedulerException;

    int insertSelective(SysTask record);

    SysTask selectByPrimaryKey(Integer id);

    int updateByPrimaryKeySelective(SysTask record);

    List<SysTask> selectByColumn(SysTask record);

    int batchInsertList(List<SysTask> record);
}
```

```java
package com.porshow.service.schedule;

import com.porshow.dao.SysTaskDao;
import com.porshow.model.SysTask;
import java.util.List;

import com.porshow.schedule.QuartzScheduler;
import lombok.extern.slf4j.Slf4j;
import org.quartz.SchedulerException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class SysTaskServiceImpl implements SysTaskService {

    @Autowired
    private SysTaskDao sysTaskDao;
    @Autowired
    QuartzScheduler quartzScheduler ;
    public int deleteByPrimaryKey(Integer id) {
        return sysTaskDao.deleteByPrimaryKey(id);
    }

    public int insert(SysTask record) throws SchedulerException {
        quartzScheduler.addJob(record.getJobClass(),record.getCronExpression());
        return sysTaskDao.insert(record);
    }

    public int insertSelective(SysTask record) {
        return sysTaskDao.insertSelective(record);
    }

    public SysTask selectByPrimaryKey(Integer id) {
        return sysTaskDao.selectByPrimaryKey(id);
    }

    public int updateByPrimaryKeySelective(SysTask record) {
        return sysTaskDao.updateByPrimaryKeySelective(record);
    }

    public List<SysTask> selectByColumn(SysTask record) {
        return sysTaskDao.selectByColumn(record);
    }

    public int batchInsertList(List<SysTask> record) {
        return sysTaskDao.batchInsertList(record);
    }

    public int updateByPrimaryKey(SysTask record) {
        return sysTaskDao.updateByPrimaryKey(record);
    }
}
```

```java
package com.porshow.model;

import io.swagger.annotations.*;
import javax.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@ApiModel
public class SysTask {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @OrderBy("desc")
    private Integer id;

    @ApiModelProperty("任务名称")
    private String taskName;

    @ApiModelProperty("说明")
    private String taskRemark;

    @ApiModelProperty("任务类")
    private String jobClass;

    @ApiModelProperty("规则表达式")
    private String cronExpression;

    @ApiModelProperty("是否启用")
    private Integer isEnable;

    @ApiModelProperty("状态")
    private Integer status;

    @ApiModelProperty("创建时间")
    private String createTime;

    @ApiModelProperty("更新时间")
    private String updateTime;

    @Transient
    @ApiModelProperty(hidden = true)
    private LocalDateTime createTimeBegin;

    @Transient
    @ApiModelProperty(hidden = true)
    private LocalDateTime createTimeEnd;
}
```

