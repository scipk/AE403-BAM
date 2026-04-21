function xNext = ballStateTransitionFcn(x)
dt = 0.005;
g  = 9.81;

xNext = [x(1) + x(4)*dt;
         x(2) + x(5)*dt;
         x(3) + x(6)*dt;
         x(4);
         x(5);
         x(6) - g*dt];
end