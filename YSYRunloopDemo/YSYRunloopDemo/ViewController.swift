//
//  ViewController.swift
//  YSYRunloopDemo
//
//  Created by shengyang_yu on 16/6/14.
//  Copyright © 2016年 yushengyang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var myThread : NSThread?
    var runLoopAddDependanceFinishFlag: Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tryTimerOnMainThread()
        
    }
    
    /***
     在viewDidLoad中调用 testRunLoop 方法
     当程序不使用GCD后台调用时 while会执行 但是卡顿执行
     当程序使用GCD后台调用时 为RunLoop加入Port程序会卡住
     这个时候线程被RunLoop带到‘坑’里去了，这个‘坑’就是一个循环，在循环中这个线程可以在没有任务的时候休眠，在有任务的时候被唤醒；当然我们只用一个while(1)也可以让这个线程一直存在，但是这个线程会一直在唤醒状态，及时它没有任务也一直处于运转状态，这对于CPU来说是非常不高效的
     ***/
    func testRunLoop() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            while true {
                print("while begin")
                let t2Runloop = NSRunLoop.currentRunLoop()
                t2Runloop.addPort(NSPort(), forMode: NSDefaultRunLoopMode)
                t2Runloop.runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
                print("while end")
            }
        }
    }
    
    /***
     在viewDidLoad中调用 performSelector: 启动方法
     能正常执行
     ***/
    func tryPerformSelectorOnMainThread() {
        self.performSelector(#selector(ViewController.mainThread), withObject: nil)
    }
    func mainThread() {
        print("exectue %s",#function)
    }
    
    /***
     在viewDidLoad中调用 performSelector::: 启动方法
     并且使用GCD后台执行 需要为线程添加一个RunLoop才能启动
     因为在调用performSelector:onThread:withObject:waitUntilDone的时候 系统会给我们创建一个Timer的source 加到对应的RunLoop上去 然而这个时候我们没有RunLoop
     ***/
    func tryPerformSelectorOnBackGroundThread() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { 
            self.performSelector(#selector(ViewController.backGroundThread), onThread: NSThread.currentThread(), withObject: nil, waitUntilDone: false)
            NSRunLoop.currentRunLoop().run()
        }
    }
    
    func backGroundThread() {
        print("\(NSThread.currentThread())")
        print("exectue %s",#function)
    }
    
    /***
     viewDidLoad中执行 alwaysLiveBackGroundThread 方法后myThread会一直存在
     但是触摸屏幕时并不会调用doBackGroundThreadWork
     需要在myThreadRun 中添加RunLoop的Source
     正常情况下，后台线程执行完任务之后就处于死亡状态，我们要避免这种情况的发生可以利用RunLoop，并且给它一个Source这样来保证线程依旧还在
     ***/
    func alwaysLiveBackGroundThread() {
        self.myThread = NSThread.init(target: self, selector: #selector(ViewController.myThreadRun), object: "etund")
        self.myThread?.start()
    }
    
    func myThreadRun() {
        
        print("my Thread Run start")
        let tRunLoop = NSRunLoop.currentRunLoop()
        tRunLoop.addPort(NSPort(), forMode: NSDefaultRunLoopMode)
//        tRunLoop.run()
        tRunLoop.runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
        /*
         添加RunLoop之后print不会执行 
         原因同 testRunLoop
         即上面的操作会使得该Thread一直存在
         */
        print("my Thread Run end")
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
//        print("myThread: \(self.myThread?.executing) \(self.myThread?.finished) \(self.myThread?.cancelled) \(self.myThread?.isMainThread)")
//        print("currentThread: \(NSThread.currentThread())")
        self.performSelector(#selector(ViewController.doBackGroundThreadWork), onThread: self.myThread!, withObject: nil, waitUntilDone: false)
    }
    
    func doBackGroundThreadWork() {
        print("do some work %s", #function)
    }
    /***
     和 performSelector::: 类似 
     当使用GCD在后台运行时 需要加入RunLoop才能启动方法
     NSTimer作为定时器当执行方法比较耗时会发生定时不准确
     CADisplayLink也可以执行定时当方法耗时会导致屏幕卡顿
     GCD也能定时
     ***/
    func tryTimerOnMainThread() {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let tTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(ViewController.timerAction), userInfo: nil, repeats: true)
            tTimer.fire()
            NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
        }
    }
    
    func timerAction() {
        
        print("timer action")
    }
    /***
     ***/
    func runLoopAddDependance() {
        
        self.runLoopAddDependanceFinishFlag = false
        
        print("start a new runloop thread")
        let tThread = NSThread.init(target: self, selector: #selector(self.handleRunLoopThreadTask), object: nil)
        tThread.start()
        
        print("start other thread")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { 
            
            /**
             这是一个while循环 
             tRunLoop run了之后相当于处于激活状态？
             **/
//            while !self.runLoopAddDependanceFinishFlag! {
                self.myThread = NSThread.currentThread()
                print("Begin RunLoop")
                let tRunLoop = NSRunLoop.currentRunLoop()
                tRunLoop.addPort(NSPort(), forMode: NSDefaultRunLoopMode)
                tRunLoop.runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
                print("End RunLoop")
                print("0:\(self.myThread)")
                self.myThread?.cancel()
                self.myThread = nil
                print("1:\(self.myThread)")
//            }
        }
        
    }
    
    func handleRunLoopThreadTask() {
        
        print("Enter Run Loop Thread")
        for i in 1...5 {
            print("In Run Loop Thread, count = \(i)")
            sleep(1);
        }
        print("Exit Run Loop Thread")
        /**
         这里要理解使用myThread调用了tryOnMyThread方法相当于获取了线程
         而线程在while中处于一直持有的状态
         改变了while的判断值
         就停止了
         当他完成了tryOnMyThread方法后才会走后面的流程
         **/
        self.performSelector(#selector(self.tryOnMyThread), onThread: self.myThread!, withObject: nil, waitUntilDone: false)
    }
    
    func tryOnMyThread() {
        /**
         这里不好理解为什么设置一个bool就结束了
         **/
        self.runLoopAddDependanceFinishFlag = true
        print("2:\(self.myThread)")
    }
    /***
     ***/
    
    /***
     ***/
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

